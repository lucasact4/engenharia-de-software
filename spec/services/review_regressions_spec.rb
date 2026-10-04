require "rails_helper"

RSpec.describe "Regressões da revisão do card 6" do
  let(:admin) { create(:user, :admin) }

  it "retira a publicação externa quando o administrador restringe a fonte" do
    alert = create(:alert, :public_request)
    publication = create(:publication, :published, kind: "occurrence", alert: alert)

    Alerts::Restrict.call(actor: admin, alert: alert, reason: "Informação sensível")

    expect(publication.reload).to be_withdrawn
    expect(PublicationPolicy::Scope.new(nil, Publication.all).resolve).not_to include(publication)
    expect {
      Publications::Publish.call(actor: admin, publication: publication)
    }.to raise_error(Pundit::NotAuthorizedError)
    expect(alert.reload.requested_visibility).to eq("public_external")
    expect(AuditEvent.for_subject(alert).last.changeset).to include("publication_blocked" => [ false, true ])

    Alerts::ChangeAudience.call(actor: alert.author, alert: alert, requested_visibility: "restricted")
    expect(alert.reload.publication_blocked?).to be(true)
    expect {
      Alerts::ChangeAudience.call(actor: alert.author, alert: alert, requested_visibility: "public_external")
    }.to raise_error(Pundit::NotAuthorizedError)
    Alerts::ChangeAudience.call(actor: admin, alert: alert, requested_visibility: "public_external", reason: "Conteúdo revisado")
    expect(alert.reload.publication_blocked?).to be(false)
  end

  it "mostra somente a versão aprovada atual mesmo com uma publicação carregada antes da revisão" do
    stale = create(:publication, body: "Rascunho com informação privada.")
    current = Publication.find(stale.id)
    Publications::Update.call(actor: admin, publication: current, attributes: { body: "Texto revisado para divulgação." })
    Publications::Submit.call(actor: admin, publication: current)
    Publications::Review.call(actor: admin, publication: current, decision: "approve", reviewed_content_version: current.content_version)
    Publications::Publish.call(actor: admin, publication: current)

    expect(PublicationProjection.new(stale).as_json[:body]).to eq("Texto revisado para divulgação.")
  end

  it "oculta o texto removido mesmo se o comentário foi carregado antes da moderação" do
    publication = create(:publication, :published)
    stale = create(:comment, publication: publication)
    Comments::Moderate.call(actor: admin, comment: Comment.find(stale.id), reason: "Exposição de dados")

    expect(CommentProjection.new(stale).as_json).to include(state: "removed", body: nil, author: nil)
  end

  it "nega curtidas usando um comentário carregado antes de sua remoção" do
    stale = create(:comment, publication: create(:publication, :published))
    Comments::Moderate.call(actor: admin, comment: Comment.find(stale.id), reason: "Exposição de dados")

    expect { Social::Interactions.like_comment(actor: create(:user), comment: stale) }
      .to raise_error(Pundit::NotAuthorizedError)
    expect(stale.comment_likes).to be_empty
  end

  it "respeita comentários desabilitados depois que a publicação foi carregada" do
    stale = create(:publication, :published)
    Publication.find(stale.id).update!(comments_enabled: false)

    expect { Comments::Create.call(actor: create(:user), publication: stale, body: "Novo comentário") }
      .to raise_error(Pundit::NotAuthorizedError)
    expect(stale.comments).to be_empty
  end

  it "respeita a retirada do perfil público ao seguir uma pessoa já carregada" do
    stale = create(:user, public_profile: true)
    User.find(stale.id).update!(public_profile: false)

    expect { Social::Interactions.follow(actor: create(:user), user: stale) }
      .to raise_error(Pundit::NotAuthorizedError)
    expect(stale.passive_follows).to be_empty
  end

  it "nega respostas usando um comentário carregado antes de sua remoção" do
    publication = create(:publication, :published)
    stale = create(:comment, publication: publication)
    Comments::Moderate.call(actor: admin, comment: Comment.find(stale.id), reason: "Exposição de dados")

    expect {
      Comments::Create.call(actor: create(:user), publication: publication, parent: stale, body: "Resposta")
    }.to raise_error(ActiveRecord::RecordInvalid)
    expect(stale.reload.replies).to be_empty
  end

  it "não permite que terceiros sincronizem uma publicação com a fonte" do
    alert = create(:alert, :public_request)
    publication = create(:publication, :published, kind: "occurrence", alert: alert)
    alert.update!(requested_visibility: "restricted")

    expect { Publications::SyncWithSource.call(actor: create(:user), alert: alert) }
      .to raise_error(Pundit::NotAuthorizedError)
    expect(publication.reload).to be_published
  end

  it "não permite usar outra fonte para retirar uma publicação" do
    publication = create(:publication, :published, kind: "occurrence", alert: create(:alert, :public_request))
    other_source = create(:alert, :restricted)

    expect {
      Publications::Withdraw.call(actor: other_source.author, publication: publication,
                                  source_alert: other_source, reason: "Restrição de outro alerta")
    }.to raise_error(Pundit::NotAuthorizedError)
    expect(publication.reload).to be_published
  end

  it "nega a desativação de contas por um administrador desativado" do
    inactive_admin = create(:user, :admin, :inactive)
    target = create(:user)

    expect { Users::Deactivate.call(actor: inactive_admin, user: target) }.to raise_error(Pundit::NotAuthorizedError)
    expect(target.reload).to be_active
  end

  it "normaliza coordenadas sem confundir valores de texto" do
    author = create(:user)
    key = SecureRandom.uuid
    first = Alerts::CreatePanic.call(actor: author, client_request_id: key,
                                    attributes: { latitude: "-8.000", longitude: "-34.900", title: "000012" })
    replay = Alerts::CreatePanic.call(actor: author, client_request_id: key,
                                     attributes: { latitude: -8.0, longitude: -34.9, title: "000012" })
    expect(replay).not_to be_created
    expect(replay.alert).to eq(first.alert)
  end

  it "distingue textos numéricos diferentes na mesma chave de pânico" do
    author = create(:user)
    key = SecureRandom.uuid
    Alerts::CreatePanic.call(actor: author, client_request_id: key, attributes: { title: "000012" })

    expect {
      Alerts::CreatePanic.call(actor: author, client_request_id: key, attributes: { title: "12" })
    }.to raise_error(Alerts::Create::IdempotencyConflict)
  end

  it "não permite que uma versão enviada pelo cliente torne um objeto antigo atual" do
    stale = create(:alert)
    current = Alert.find(stale.id)
    Alerts::Transition.call(actor: admin, alert: current, to: "triaging")

    expect {
      Alerts::UpdateContent.call(actor: stale.author, alert: stale, lock_version: current.lock_version,
                                attributes: { title: "Edição após início da triagem" })
    }.to raise_error(ActiveRecord::StaleObjectError)
    expect(current.reload.title).to eq("Lâmpada queimada no corredor")
  end
end
