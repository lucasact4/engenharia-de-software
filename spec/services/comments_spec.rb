require "rails_helper"

RSpec.describe "Comment services" do
  let(:publication) { create(:publication, :published) }
  let(:author) { create(:user) }
  let(:admin) { create(:user, :admin) }

  def comment!(body = "Comentário raiz", parent: nil, actor: author, on: publication)
    Comments::Create.call(actor: actor, publication: on, body: body, parent: parent)
  end

  it "supports a root comment and one level of replies" do
    root = comment!
    reply = comment!("Resposta", parent: root, actor: create(:user))

    expect(reply.parent).to eq(root)
    expect { comment!("Resposta da resposta", parent: reply) }
      .to raise_error(ActiveRecord::RecordInvalid, /só é possível responder a um comentário raiz/)
  end

  it "requires the parent to belong to the same publication" do
    other_root = comment!(on: create(:publication, :published))

    expect { comment!("Resposta cruzada", parent: other_root) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "keeps publication, author and parent immutable" do
    root = comment!
    reply = comment!("Resposta", parent: root)

    reply.parent = nil
    expect(reply).not_to be_valid
    reply.reload.author = create(:user)
    expect(reply).not_to be_valid
  end

  it "rejects empty and oversized bodies" do
    expect { comment!("   ") }.to raise_error(ActiveRecord::RecordInvalid)
    expect { comment!("a" * 2001) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "lets the author edit and delete while keeping replies and a tombstone" do
    root = comment!
    reply = comment!("Resposta", parent: root, actor: create(:user))

    Comments::Update.call(actor: author, comment: root, body: "Texto editado")
    expect(root.reload).to have_attributes(body: "Texto editado", edited_at: be_present)

    Comments::Delete.call(actor: author, comment: root)
    projection = CommentProjection.new(root.reload, viewer: author).as_json
    expect(projection).to include(state: "deleted", body: nil, author: nil)
    expect(reply.reload.parent).to eq(root)
    expect(CommentProjection.new(reply, viewer: nil).as_json[:body]).to eq("Resposta")
  end

  it "denies edits by other people" do
    root = comment!

    expect { Comments::Update.call(actor: create(:user), comment: root, body: "Invasão") }.to raise_error(Pundit::NotAuthorizedError)
  end

  it "lets admins moderate with reason and audit, preserving the original text only for admins" do
    root = comment!("Conteúdo ofensivo")
    expect { Comments::Moderate.call(actor: admin, comment: root, reason: "") }.to raise_error(ActiveRecord::RecordInvalid)

    Comments::Moderate.call(actor: admin, comment: root, reason: "Ofensa")

    expect(root.reload.body).to eq("Conteúdo ofensivo")
    expect(CommentProjection.new(root, viewer: nil).as_json).to include(state: "removed", body: nil)
    expect(AuditEvent.for_subject(root).last).to have_attributes(action: "comment.removed", reason: "Ofensa")
    expect { Comments::Moderate.call(actor: author, comment: root, reason: "x") }.to raise_error(Pundit::NotAuthorizedError)
  end

  it "inherits current publication access" do
    root = comment!
    Publications::Withdraw.call(actor: admin, publication: publication, reason: "Teste")

    expect(PublicationCommentsQuery.new(author, publication).call).to be_empty
    expect { comment!("Depois da retirada") }.to raise_error(Pundit::NotAuthorizedError)
    expect { Comments::Update.call(actor: author, comment: root, body: "Edição") }.to raise_error(Pundit::NotAuthorizedError)
  end

  it "shows a neutral identity when the author has no public profile" do
    root = comment!
    public_author = create(:user, :public_profile, display_name: "Pessoa Pública")
    public_comment = comment!("Olá", actor: public_author)

    expect(CommentProjection.new(root, viewer: nil).as_json[:author]).to eq(display_name: "Pessoa usuária", username: nil, public_profile: false, id: nil, verified: false)
    expect(CommentProjection.new(public_comment, viewer: nil).as_json[:author]).to include(display_name: "Pessoa Pública")
    expect(CommentProjection.new(public_comment, viewer: nil).as_json.to_s).not_to include(public_author.email_address)
  end
end
