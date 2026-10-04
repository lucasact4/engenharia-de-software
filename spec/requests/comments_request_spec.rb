require "rails_helper"

RSpec.describe "Comments", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:author) { create(:user, :public_profile, display_name: "Ana Comentarista") }
  let(:reader) { create(:user) }
  let!(:publication) { create(:publication, :published) }

  it "creates a root comment and a one-level reply, escaping HTML" do
    sign_in(author)
    post publication_comments_path(publication), params: { body: "<script>alert('x')</script> Linha 1\nLinha 2" }
    root = Comment.last
    expect(response).to redirect_to(publication_path(publication, anchor: "comment_#{root.id}", locale: I18n.locale))

    sign_in(reader)
    post publication_comments_path(publication), params: { body: "Resposta direta", parent_id: root.id }
    reply = Comment.last
    expect(reply.parent).to eq(root)

    get publication_path(publication)
    expect(response.body).not_to include("<script>alert('x')</script>")
    expect(response.body).to include("&lt;script&gt;")
    expect(response.body).to include("Ana Comentarista")
    expect(response.body).to include(person_path(author, locale: I18n.locale))
    expect(response.body).not_to include(author.email_address)
  end

  it "rejects replies to replies, parents from other publications and invalid lengths" do
    root = create(:comment, publication: publication)
    reply = create(:comment, publication: publication, parent: root)
    other = create(:comment, publication: create(:publication, :published))
    sign_in(reader)

    expect { post publication_comments_path(publication), params: { body: "Nível 2", parent_id: reply.id } }.not_to change(Comment, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Nível 2")

    expect { post publication_comments_path(publication), params: { body: "Cruzado", parent_id: other.id } }.not_to change(Comment, :count)
    expect(response).to have_http_status(:unprocessable_entity)

    expect { post publication_comments_path(publication), params: { body: "x", parent_id: "999999" } }.not_to change(Comment, :count)
    expect { post publication_comments_path(publication), params: { body: "   " } }.not_to change(Comment, :count)
    expect { post publication_comments_path(publication), params: { body: "a" * 2001 } }.not_to change(Comment, :count)
  end

  it "revalidates access and comments_enabled when the page was opened before a change" do
    sign_in(reader)
    get publication_path(publication)

    publication.update_columns(comments_enabled: false)
    post publication_comments_path(publication), params: { body: "Depois de desligar" }
    expect(response).to have_http_status(:forbidden)

    publication.update_columns(comments_enabled: true)
    Publications::Withdraw.call(actor: admin, publication: publication, reason: "Retirada")
    post publication_comments_path(publication), params: { body: "Depois da retirada" }
    expect(response).to have_http_status(:not_found)
    expect(Comment.count).to eq(0)
  end

  it "lets the author edit (marked as edited) and delete without exposing the body afterwards" do
    comment = create(:comment, publication: publication, author: author, body: "Texto original privado depois")
    reply = create(:comment, publication: publication, parent: comment, author: reader, body: "Resposta de outra pessoa")
    sign_in(author)

    patch comment_path(comment), params: { body: "Texto editado", lock_version: comment.lock_version }
    expect(comment.reload).to have_attributes(body: "Texto editado", edited_at: be_present)

    delete comment_path(comment)
    get publication_path(publication)
    expect(response.body).to include("Comentário apagado pelo autor.")
    expect(response.body).not_to include("Texto editado")
    expect(response.body).to include("Resposta de outra pessoa")
    expect(reply.reload).not_to be_hidden

    sign_in(reader)
    patch comment_path(comment), params: { body: "Invasão" }
    expect(response).to have_http_status(:forbidden)
  end

  it "returns 409 for a stale comment edit and keeps the text" do
    comment = create(:comment, publication: publication, author: author)
    sign_in(author)
    stale = comment.lock_version
    comment.update!(body: "Editado em outra aba")

    patch comment_path(comment), params: { body: "Meu texto novo", lock_version: stale }

    expect(response).to have_http_status(:conflict)
    expect(response.body).to include("Meu texto novo")
  end

  it "never leaks moderated text or authorship in HTML or Turbo responses, and blocks new replies and likes" do
    comment = create(:comment, publication: publication, author: author, body: "Conteúdo ofensivo removido")
    Comments::Moderate.call(actor: admin, comment: comment, reason: "Assédio")
    sign_in(reader)

    get publication_path(publication)
    expect(response.body).to include("Comentário removido pela moderação.")
    expect(response.body).not_to include("Conteúdo ofensivo removido")
    expect(response.body).not_to include("Ana Comentarista")

    post comment_like_path(comment)
    expect(response).to have_http_status(:forbidden)
    post publication_comments_path(publication), params: { body: "Tentando responder", parent_id: comment.id }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(CommentLike.count).to eq(0)

    get comment_path(comment)
    expect(response.body).not_to include("Conteúdo ofensivo removido")
  end

  it "likes comments idempotently" do
    comment = create(:comment, publication: publication)
    sign_in(reader)

    2.times { post comment_like_path(comment) }
    expect(CommentLike.where(user: reader).count).to eq(1)
    2.times { delete comment_like_path(comment) }
    expect(CommentLike.count).to eq(0)
  end

  it "paginates roots and limits replies with a link to the full thread" do
    root = create(:comment, publication: publication)
    7.times { |index| create(:comment, publication: publication, parent: root, body: "Resposta número #{index}") }
    get publication_path(publication)

    expect(response.body).to include("Resposta número 4")
    expect(response.body).not_to include("Resposta número 6")
    expect(response.body).to include("Ver todas as 7 respostas")

    get comment_path(root)
    expect(response.body).to include("Resposta número 6")
  end
end
