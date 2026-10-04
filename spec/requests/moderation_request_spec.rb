require "rails_helper"

RSpec.describe "Reports and moderation", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:reporter) { create(:user, email_address: "denunciante@example.com") }
  let!(:publication) { create(:publication, :published) }
  let!(:comment) { create(:comment, publication: publication, body: "Comentário denunciado") }

  it "lets a reader report a comment once, privately" do
    sign_in(reporter)

    2.times { post comment_content_reports_path(comment), params: { reason: "harassment" } }
    expect(ContentReport.where(reporter: reporter).count).to eq(1)

    post comment_content_reports_path(comment), params: { reason: "other" }
    expect(ContentReport.count).to eq(1)

    sign_in(create(:user))
    get publication_path(publication)
    expect(response.body).not_to include("denunciante@example.com")
    expect(response.body).not_to include("Assédio")

    get content_report_path(ContentReport.last)
    expect(response).to have_http_status(:not_found)
  end

  it "requires details for 'other' and does not hide content by itself" do
    sign_in(reporter)
    post publication_content_reports_path(publication), params: { reason: "other", details: "" }
    expect(response).to have_http_status(:unprocessable_entity)

    post publication_content_reports_path(publication), params: { reason: "misinformation" }
    expect(publication.reload).to be_published
  end

  it "reviews reports separately from moderation, with audit and explicit actions" do
    report = ContentReports::Create.call(actor: reporter, target: comment, reason: "harassment")
    sign_in(admin)

    get admin_content_reports_path
    expect(response.body).to include(publication.title)
    expect(response.body).not_to include("denunciante@example.com")

    get admin_content_report_path(report)
    expect(response.body).to include("denunciante@example.com")

    patch review_admin_content_report_path(report), params: { decision: "actioned", notes: "Confirmado" }
    expect(report.reload).to be_actioned
    expect(comment.reload).not_to be_removed

    patch moderate_admin_comment_path(comment), params: { reason: "", return_to: admin_content_report_path(report) }
    expect(comment.reload).not_to be_removed

    patch moderate_admin_comment_path(comment), params: { reason: "Assédio confirmado", return_to: "https://evil.example" }
    expect(comment.reload).to be_removed
    expect(response).to redirect_to(admin_publication_path(publication, locale: I18n.locale))
    expect(AuditEvent.where(subject: comment, action: "comment.removed")).to exist
  end

  it "lets the reporter reopen a decided report with new information" do
    report = ContentReports::Create.call(actor: reporter, target: publication, reason: "spam")
    ContentReports::Review.call(actor: admin, report: report, decision: "dismissed")
    sign_in(reporter)

    patch reopen_content_report_path(report), params: { details: "" }
    expect(response).to have_http_status(:unprocessable_entity)

    patch reopen_content_report_path(report), params: { details: "Novas mensagens publicadas" }
    expect(report.reload).to be_pending
  end

  it "keeps the moderation endpoints closed to regular users" do
    sign_in(reporter)

    patch moderate_admin_comment_path(comment), params: { reason: "abuso" }
    expect(response).to redirect_to(panel_path(locale: I18n.locale))
    expect(comment.reload).not_to be_removed

    get admin_content_reports_path
    expect(response).to redirect_to(panel_path(locale: I18n.locale))
  end
end
