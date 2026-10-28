require "rails_helper"

RSpec.describe TurnstileVerifier do
  it "accepts a token only when Siteverify reports success" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("TURNSTILE_SITE_KEY").and_return("site-key")
    allow(ENV).to receive(:[]).with("TURNSTILE_SECRET_KEY").and_return("server-secret")
    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return('{"success":true,"action":"anonymous_occurrence","hostname":"sgu.example"}')
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).with("challenges.cloudflare.com", 443).and_return(http)
    allow(http).to receive(:use_ssl=).with(true)
    allow(http).to receive(:open_timeout=).with(3)
    allow(http).to receive(:read_timeout=).with(3)
    allow(http).to receive(:start).and_yield(http)
    expect(http).to receive(:request) do |request|
      expect(URI.decode_www_form(request.body)).to contain_exactly(
        ["secret", "server-secret"], ["response", "valid-token"]
      )
      response
    end

    expect(described_class.verify("valid-token", expected_hostname: "sgu.example")).to be(true)
  end

  it "rejects missing configuration without contacting Siteverify" do
    allow(described_class).to receive(:configured?).and_return(false)
    expect(Net::HTTP).not_to receive(:new)

    expect(described_class.verify("token")).to be(false)
  end

  it "rejects oversized tokens without contacting Siteverify" do
    allow(described_class).to receive(:configured?).and_return(true)
    expect(Net::HTTP).not_to receive(:new)

    expect(described_class.verify("x" * (described_class::MAX_TOKEN_LENGTH + 1))).to be(false)
  end
end