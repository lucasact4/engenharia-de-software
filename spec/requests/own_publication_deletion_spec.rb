require "rails_helper"

RSpec.describe "Exclusão pelo autor", type: :request do
  it "requires the displayed word and keeps a deleted post out of the mural" do
    author = create(:user)
    result = Alerts::CreateOccurrence.call(actor: author, attributes: occurrence_attributes(
      location_source: "manual", location_description: "Corredor da biblioteca", latitude: nil, longitude: nil
    ))
    post = result.alert.publication
    sign_in(author)
    get publication_path(post)
    html = Nokogiri::HTML(response.body)
    expect(html.text).to include("Local informado:", "Corredor da biblioteca")
    challenge = html.at_css('input[name="challenge"]')["value"]
    word = html.at_css('label[for="confirmation"]').text.split.fetch(1)

    delete publication_path(post), params: { challenge: challenge, confirmation: "incorreta" }
    expect(post.reload).to be_published

    delete publication_path(post), params: { challenge: challenge, confirmation: word }
    expect(post.reload).to be_withdrawn
    expect(AuditEvent.for_subject(post).exists?(actor: author, action: "publication.deleted")).to be(true)
    expect(PublicationPolicy::FeedScope.new(author, Publication.all).resolve).not_to include(post)
  end
end
