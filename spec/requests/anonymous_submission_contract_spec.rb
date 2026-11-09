require "rails_helper"

RSpec.describe "RF005 authenticated concealed submission contract", type: :request do
  let(:author) { create(:user, :public_profile) }

  def submit(path: alerts_path, token: "submitted-token", extra: {}, attributes: {})
    post path, params: {
      client_request_id: SecureRandom.uuid,
      "cf-turnstile-response" => token,
      alert: occurrence_attributes(requested_visibility: "public_external", anonymous_public: true).merge(attributes)
    }.merge(extra)
  end

  it "requires an account even when a visitor supplies a valid token and a forged author" do
    expect(TurnstileVerifier).not_to receive(:verify)
    expect { submit(attributes: { author_id: author.id }) }.not_to change(Alert, :count)
    expect(response).to redirect_to(new_session_path(locale: I18n.locale))
    expect(AnonymousSubmissionAudit.count).to eq(0)
  end

  it "passes the standard widget field to verification and retains the authenticated author and protected audit" do
    sign_in(author)
    expect(TurnstileVerifier).to receive(:verify).with("submitted-token", expected_hostname: "www.example.com").and_return(true)
    expect { submit(attributes: { author_id: create(:user).id }) }
      .to change(Alert, :count).by(1).and change(AnonymousSubmissionAudit, :count).by(1)

    alert = Alert.order(:id).last
    expect(alert.author).to eq(author)
    expect(alert).to be_anonymous_public
    audit = alert.anonymous_submission_audit
    expect(audit.ip_address).to be_present
    expect(audit.submitted_at).to be_present
    expect(audit.ip_address_ciphertext).not_to eq(audit.ip_address)
  end

  it "does not accept a missing token or the former underscore field as a fallback" do
    sign_in(author)
    expect(Net::HTTP).not_to receive(:new)
    [ {}, { cf_turnstile_response: "legacy-token" } ].each do |extra|
      expect { submit(token: nil, extra: extra) }.not_to change(Alert, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
    expect(AnonymousSubmissionAudit.count).to eq(0)
  end

  it "fails closed without configuration while preserving the report and disabling concealment" do
    sign_in(author)
    allow(TurnstileVerifier).to receive(:configured?).and_return(false)
    expect(Net::HTTP).not_to receive(:new)
    expect { submit(attributes: { title: "Relato preservado após falha" }) }.not_to change(Alert, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Relato preservado após falha", "indisponível até")
    checkbox = Nokogiri::HTML(response.body).at_css("#alert_anonymous_public")
    expect(checkbox["disabled"]).to be_present
  end

  it "does not echo a failed verification token back into the form" do
    sign_in(author)
    allow(TurnstileVerifier).to receive(:configured?).and_return(true)
    expect(TurnstileVerifier).to receive(:verify).with("private-failed-token", expected_hostname: "www.example.com").and_return(false)
    expect { submit(token: "private-failed-token") }.not_to change(Alert, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).not_to include("private-failed-token")
  end

  it "does not challenge an ordinary authenticated submission" do
    sign_in(author)
    expect(TurnstileVerifier).not_to receive(:verify)
    expect { submit(token: nil, attributes: { anonymous_public: "0" }) }.to change(Alert, :count).by(1)
    expect(AnonymousSubmissionAudit.count).to eq(0)
  end

  it "enforces the same challenge on administrative creation" do
    admin = create(:user, :admin)
    sign_in(admin)
    allow(TurnstileVerifier).to receive(:configured?).and_return(true)
    expect(TurnstileVerifier).to receive(:verify).with(nil, expected_hostname: "www.example.com").and_return(false)
    expect { submit(path: admin_alerts_path, token: nil) }.not_to change(Alert, :count)
    expect(response).to have_http_status(:unprocessable_entity)

    expect(TurnstileVerifier).to receive(:verify).with("submitted-token", expected_hostname: "www.example.com").and_return(true)
    submit(path: admin_alerts_path)
    alert = Alert.order(:id).last
    expect(response).to redirect_to(admin_alert_path(alert, locale: I18n.locale))
    expect(alert.author).to eq(admin)
    expect(alert.anonymous_submission_audit).to be_present
  end

  it "filters both standard and obsolete challenge fields from request logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter("cf-turnstile-response" => "private-token", "cf_turnstile_response" => "legacy-token")
    expect(filtered.values).to eq([ "[FILTERED]", "[FILTERED]" ])
  end
end
