require "rails_helper"

RSpec.describe "Content report services" do
  let(:reporter) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:publication) { create(:publication, :published) }
  let(:comment) { create(:comment, publication: publication) }

  it "creates one report per reporter and target" do
    first = ContentReports::Create.call(actor: reporter, target: publication, reason: "spam")
    again = ContentReports::Create.call(actor: reporter, target: publication, reason: "privacy")

    expect(again).to eq(first)
    expect(ContentReport.count).to eq(1)
    expect(ContentReports::Create.call(actor: reporter, target: comment, reason: "harassment")).to be_persisted
  end

  it "requires details for other and access to the target" do
    expect { ContentReports::Create.call(actor: reporter, target: publication, reason: "other") }.to raise_error(ActiveRecord::RecordInvalid)
    expect { ContentReports::Create.call(actor: reporter, target: create(:publication), reason: "spam") }.to raise_error(Pundit::NotAuthorizedError)

    Publications::Withdraw.call(actor: admin, publication: publication, reason: "Teste")
    expect { ContentReports::Create.call(actor: reporter, target: comment, reason: "spam") }.to raise_error(Pundit::NotAuthorizedError)
  end

  it "is visible only to the reporter and admins, never to the reported author" do
    report = ContentReports::Create.call(actor: reporter, target: comment, reason: "harassment")

    expect(ContentReportPolicy::Scope.new(reporter, ContentReport.all).resolve).to contain_exactly(report)
    expect(ContentReportPolicy::Scope.new(comment.author, ContentReport.all).resolve).to be_empty
    expect(ContentReportPolicy.new(comment.author, report).show?).to be(false)
    expect(ContentReportPolicy::Scope.new(admin, ContentReport.all).resolve).to contain_exactly(report)
  end

  it "does not hide content automatically regardless of report volume" do
    5.times { ContentReports::Create.call(actor: create(:user), target: publication, reason: "spam") }

    expect(PublicationPolicy::Scope.new(nil, Publication.all).resolve).to include(publication)
  end

  it "lets only admins review with audit, and the reporter reopen with new details" do
    report = ContentReports::Create.call(actor: reporter, target: publication, reason: "spam")
    expect { ContentReports::Review.call(actor: reporter, report: report, decision: "dismissed") }.to raise_error(Pundit::NotAuthorizedError)

    ContentReports::Review.call(actor: admin, report: report, decision: "dismissed", notes: "Sem violação")
    expect(report.reload).to have_attributes(state: "dismissed", reviewed_by: admin)
    expect(AuditEvent.for_subject(report).last).to have_attributes(action: "content_report.reviewed", actor: admin)

    ContentReports::Reopen.call(actor: reporter, report: report, details: "Novas evidências do mesmo problema")
    expect(report.reload).to be_pending
  end
end
