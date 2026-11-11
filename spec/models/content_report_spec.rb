require "rails_helper"

RSpec.describe ContentReport, type: :model do
  # RF013: validate the report itself, without saving or triggering notifications.
  let(:reporter) { build_stubbed(:user) }
  let(:publication) { build_stubbed(:publication) }
  let(:comment) { build_stubbed(:comment, publication: publication) }

  def report_with(**attributes)
    described_class.new({ reporter: reporter, publication: publication, reason: "spam" }.merge(attributes))
  end

  describe "RF013 — report acceptance criteria" do
    it "RF013-UT01 accepts a report targeting only a publication" do
      report = report_with

      expect(report).to be_valid
      expect(report.target).to eq(publication)
    end

    it "RF013-UT02 accepts a report targeting only a comment" do
      report = report_with(publication: nil, comment: comment)

      expect(report).to be_valid
      expect(report.target).to eq(comment)
      expect(report.target_publication).to eq(publication)
    end

    it "RF013-UT03 rejects a report without a target" do
      report = report_with(publication: nil)

      expect(report).not_to be_valid
      expect(report.errors.of_kind?(:base, :single_target)).to be(true)
    end

    it "RF013-UT04 rejects a report targeting a publication and a comment together" do
      report = report_with(comment: comment)

      expect(report).not_to be_valid
      expect(report.errors.of_kind?(:base, :single_target)).to be(true)
    end

    it "RF013-UT05 rejects a report without its reporter" do
      report = report_with(reporter: nil)

      expect(report).not_to be_valid
      expect(report.errors.of_kind?(:reporter, :blank)).to be(true)
    end

    it "RF013-UT06 rejects a reason outside the supported choices" do
      report = report_with(reason: "unsupported")

      expect(report).not_to be_valid
      expect(report.errors.of_kind?(:reason, :inclusion)).to be(true)
    end

    it "RF013-UT07 requires details when the reason is other" do
      report = report_with(reason: "other", details: nil)

      expect(report).not_to be_valid
      expect(report.errors.of_kind?(:details, :blank)).to be(true)
    end

    it "RF013-UT08 does not accept whitespace as the explanation for other" do
      report = report_with(reason: "other", details: "  \n\t  ")

      expect(report).not_to be_valid
      expect(report.errors.of_kind?(:details, :blank)).to be(true)
    end

    it "RF013-UT09 accepts other with a concrete explanation" do
      report = report_with(reason: "other", details: "  O conteúdo expõe dados pessoais.  ")

      expect(report).to be_valid
      expect(report.details).to eq("O conteúdo expõe dados pessoais.")
    end

    it "RF013-UT10 accepts details at the 2000-character limit" do
      report = report_with(details: "a" * 2000)

      expect(report).to be_valid
    end

    it "RF013-UT11 rejects details exceeding the limit by one character" do
      report = report_with(details: "a" * 2001)

      expect(report).not_to be_valid
      expect(report.errors.of_kind?(:details, :too_long)).to be(true)
    end
  end
end
