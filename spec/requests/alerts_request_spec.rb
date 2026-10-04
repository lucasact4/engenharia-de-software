require "rails_helper"

RSpec.describe "Alerts (portal)", type: :request do
  let(:author) { create(:user) }
  let(:category) { create(:category) }
  let(:key) { SecureRandom.uuid }

  def form_params(overrides = {})
    {
      title: "Lâmpada queimada no bloco",
      description: "Corredor do primeiro andar sem iluminação desde ontem.",
      category_id: category.id,
      location_source: "gps",
      latitude: "-8.0171234",
      longitude: "-34.9501234",
      location_accuracy_meters: "12.5",
      location_captured_at: 1.minute.ago.iso8601,
      requested_visibility: "internal",
      reported_severity: ""
    }.merge(overrides)
  end

  # Aceita create_alert(title: ...) ou create_alert({ ... }, client_request_id: ..., extra: ...).
  def create_alert(overrides = {}, **options)
    overrides = overrides.merge(options)
    client_request_id = overrides.delete(:client_request_id) || key
    extra = overrides.delete(:extra) || {}
    post alerts_path, params: { client_request_id: client_request_id, alert: form_params(overrides) }.merge(extra)
  end

  describe "registration" do
    before { sign_in(author) }

    it "renders the form with a stable submission key and allows describing a location without a catalog" do
      get new_alert_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="client_request_id"')
      expect(response.body).to include("Descrição do local")
      expect(response.body).to include('name="alert[title]"')
      expect(response.body).not_to include("alert[author_id]")
      expect(response.body).not_to include("alert[status]")
      expect(response.body).not_to include("alert[priority]")
    end

    it "creates an occurrence by GPS with the session author, shows the protocol and keeps it restricted to the backend fields" do
      expect { create_alert }.to change(Alert, :count).by(1)

      alert = Alert.last
      expect(response).to redirect_to(alert_path(alert, locale: I18n.locale))
      expect(alert.author).to eq(author)
      expect(alert).to have_attributes(status: "received", priority: nil, visibility: "internal", reported_severity: nil,
                                       location_source: "gps", location_id: nil)
      follow_redirect!
      expect(response.body).to include(alert.protocol)
    end

    it "ignores author, status, priority and visibility sent by the client" do
      other = create(:user)
      create_alert(author_id: other.id, status: "resolved", priority: "urgent", visibility: "internal",
                   assessed_severity: "critical", publication_blocked: "1", requested_visibility: "restricted")

      alert = Alert.last
      expect(alert.author).to eq(author)
      expect(alert).to have_attributes(status: "received", priority: nil, assessed_severity: nil,
                                       visibility: "restricted", publication_blocked: false)
    end

    it "creates by manual location without copying the location reference coordinates" do
      location = create(:location, reference_latitude: -8.01, reference_longitude: -34.95)
      create_alert(location_source: "manual", location_id: location.id, latitude: "-8.5", longitude: "-35.0")

      alert = Alert.last
      expect(alert).to have_attributes(location_source: "manual", location: location, latitude: nil, longitude: nil,
                                       location_accuracy_meters: nil, location_captured_at: nil)
    end

    it "rejects an inactive location and keeps what the person typed" do
      location = create(:location, active: false)
      create_alert(location_source: "manual", location_id: location.id, description: "Relato preservado aqui")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Relato preservado aqui")
      expect(response.body).to include("está inativo e não pode ser escolhido")
      expect(response.body).to include(key)
    end

    it "requires a location for ordinary occurrences (no unavailable source)" do
      expect { create_alert(location_source: "unavailable", latitude: nil, longitude: nil) }.not_to change(Alert, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "validates GPS pairs, ranges and capture metadata on the server" do
      [
        { latitude: "-8.0", longitude: "" },
        { latitude: "-91", longitude: "-34" },
        { latitude: "abc", longitude: "-34" },
        { location_accuracy_meters: "-1" },
        { location_captured_at: 2.hours.from_now.iso8601 },
        { location_captured_at: 3.days.ago.iso8601 },
        { location_captured_at: "não é data" }
      ].each do |overrides|
        expect { create_alert(overrides, client_request_id: SecureRandom.uuid) }.not_to change(Alert, :count), overrides.inspect
        expect(response).to have_http_status(:unprocessable_entity), overrides.inspect
      end
    end

    it "enforces text limits and category details" do
      other = create(:category, :other)
      create_alert(title: "abc", description: "curto")
      expect(response).to have_http_status(:unprocessable_entity)

      create_alert({ category_id: other.id, category_other_description: "" }, client_request_id: SecureRandom.uuid)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Qual situação?")

      create_alert({ category_id: other.id, category_other_description: "Fiação exposta perto da quadra" }, client_request_id: SecureRandom.uuid)
      expect(Alert.last.category_other_description).to eq("Fiação exposta perto da quadra")
    end

    it "drops category details when the category does not require them" do
      create_alert(category_other_description: "texto que não se aplica")

      expect(Alert.last.category_other_description).to be_nil
    end

    it "does not duplicate on retry with the same key and payload" do
      create_alert
      expect { create_alert }.not_to change(Alert, :count)

      expect(response).to redirect_to(alert_path(Alert.last, locale: I18n.locale))
      follow_redirect!
      expect(response.body).to include("nada foi duplicado")
    end

    it "returns 409 for the same key with different content and only uses a new key on explicit choice" do
      create_alert
      existing = Alert.last

      expect { create_alert(description: "Outro relato diferente") }.not_to change(Alert, :count)
      expect(response).to have_http_status(:conflict)
      expect(response.body).to include("Outro relato diferente")
      expect(response.body).to include(existing.protocol)

      replacement = SecureRandom.uuid
      expect do
        create_alert({ description: "Outro relato diferente" }, extra: { new_intent: "1", replacement_client_request_id: replacement })
      end.to change(Alert, :count).by(1)
      expect(Alert.last.client_request_id).to eq(replacement)
    end

    it "accepts real PNG/JPEG photos and rejects forged or excessive files" do
      create_alert({ photos: [ uploaded_photo, uploaded_photo(bytes: SguSupport::JPEG_BYTES, filename: "b.jpg", content_type: "image/jpeg") ] })
      expect(Alert.last.photos.count).to eq(2)

      fake = uploaded_photo(bytes: "GIF89a-not-png".b, filename: "x.png", content_type: "image/png")
      expect { create_alert({ photos: [ fake ] }, client_request_id: SecureRandom.uuid) }.not_to change(Alert, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Selecione as fotos novamente")

      six = Array.new(6) { uploaded_photo }
      expect { create_alert({ photos: six }, client_request_id: SecureRandom.uuid) }.not_to change(Alert, :count)

      big = uploaded_photo(bytes: SguSupport::PNG_BYTES + ("0" * (Alert::MAX_PHOTO_BYTES + 1)).b)
      expect { create_alert({ photos: [ big ] }, client_request_id: SecureRandom.uuid) }.not_to change(Alert, :count)
    end

    it "does not accept blob signed ids as photos" do
      other = Alerts::CreateOccurrence.call(actor: create(:user), attributes: occurrence_attributes, photos: [ photo ]).alert
      signed_id = other.photos.first.blob.signed_id

      expect { create_alert(photos: [ signed_id ]) }.to change(Alert, :count).by(1)
      expect(Alert.last.photos).to be_empty
    end
  end

  describe "listing and reading" do
    let!(:mine) { create(:alert, author: author, title: "Meu registro de teste") }
    let!(:internal_other) { create(:alert, title: "Ocorrência interna alheia") }
    let!(:restricted_other) { create(:alert, :restricted, title: "Registro restrito alheio") }

    before { sign_in(author) }

    it "lists own alerts, internal occurrences and never restricted alerts of others" do
      get alerts_path
      expect(response.body).to include("Meu registro de teste")
      expect(response.body).not_to include("Ocorrência interna alheia")

      get alerts_path(aba: "internos")
      expect(response.body).to include("Ocorrência interna alheia")
      expect(response.body).not_to include("Registro restrito alheio")

      get alerts_path(aba: "internos", q: "restrito")
      expect(response.body).not_to include("Registro restrito alheio")
    end

    it "returns 404 for a restricted alert of another person" do
      get alert_path(restricted_other)

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include("Registro restrito alheio")
    end

    it "hides author, coordinates and photos from internal readers" do
      get alert_path(internal_other)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(internal_other.author.email_address)
      expect(response.body).not_to include("-34.9")
      expect(response.body).not_to include("-34,9")
      expect(response.body).not_to include("/fotos/")
      expect(response.body).to include("coordenadas restritas")
    end

    it "shows the author their own coordinates" do
      get alert_path(mine)

      expect(response.body).to include("-8.000000, -34.900000")
      expect(response.body).to include("Você")
    end
  end

  describe "content edit by the author" do
    let!(:alert) { create(:alert, author: author) }

    before { sign_in(author) }

    it "updates while received and records the audit" do
      patch alert_path(alert), params: { lock_version: alert.lock_version, alert: form_params(title: "Título corrigido pelo autor") }

      expect(response).to redirect_to(alert_path(alert, locale: I18n.locale))
      expect(alert.reload.title).to eq("Título corrigido pelo autor")
      expect(AuditEvent.where(subject: alert, action: "alert.content_updated")).to exist
    end

    it "returns 409 on a stale lock_version and keeps the typed text" do
      stale = alert.lock_version
      alert.update!(description: "Mudado por outra aba desde a abertura.")

      patch alert_path(alert), params: { lock_version: stale, alert: form_params(description: "Texto que não pode se perder") }

      expect(response).to have_http_status(:conflict)
      expect(response.body).to include("Texto que não pode se perder")
      expect(alert.reload.description).not_to eq("Texto que não pode se perder")
    end

    it "allows the author after triage and forbids other people" do
      alert.update_columns(status: "triaging")
      get edit_alert_path(alert)
      expect(response).to have_http_status(:ok)

      sign_in(create(:user))
      patch alert_path(alert), params: { alert: form_params(title: "Invasão de edição") }
      expect(response).to have_http_status(:forbidden)
      expect(alert.reload.title).not_to eq("Invasão de edição")
    end

    it "lets the author request public visibility pending approval" do
      alert.update_columns(requested_visibility: "public_external", visibility: "restricted")

      patch audience_alert_path(alert), params: { lock_version: alert.lock_version, requested_visibility: "public_external" }

      expect(alert.reload).to have_attributes(requested_visibility: "public_external", visibility: "restricted")
      expect(alert.publication).to have_attributes(state: "published", visibility: "internal", review_status: "pending")
    end

    it "removes one of the author's photos with an audit and never another alert's attachment" do
      with_photo = Alerts::CreateOccurrence.call(actor: author, attributes: occurrence_attributes, photos: [ photo, photo ]).alert
      foreign = Alerts::CreateOccurrence.call(actor: create(:user), attributes: occurrence_attributes, photos: [ photo ]).alert

      delete alert_photo_path(alert_id: with_photo.id, id: foreign.photos_attachments.first.id), params: { lock_version: with_photo.lock_version }
      expect(response).to have_http_status(:not_found)
      expect(foreign.photos.count).to eq(1)

      attachment = with_photo.photos_attachments.first
      expect do
        delete alert_photo_path(alert_id: with_photo.id, id: attachment.id), params: { lock_version: with_photo.reload.lock_version }
      end.to change { with_photo.photos_attachments.count }.by(-1)
      expect(AuditEvent.where(subject: with_photo, action: "alert.photo_removed")).to exist

      get alert_photo_path(alert_id: with_photo.id, id: attachment.id)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "following an occurrence" do
    let!(:internal) { create(:alert) }

    before { sign_in(author) }

    it "subscribes idempotently and unsubscribes even after losing access" do
      2.times { post alert_subscription_path(internal) }
      expect(AlertSubscription.where(user: author, alert: internal).count).to eq(1)

      internal.update_columns(requested_visibility: "restricted", visibility: "restricted")
      get alerts_path(aba: "acompanhados")
      expect(response.body).not_to include(internal.title)
      expect(response.body).to include("deixou de estar acessível")

      delete alert_subscription_path(internal)
      expect(AlertSubscription.where(user: author)).to be_empty
      expect(response).to redirect_to(follow_ups_path(locale: I18n.locale))
    end

    it "cannot subscribe to panic or inaccessible alerts" do
      panic = create(:alert, :panic)
      post alert_subscription_path(panic)

      expect(response).to have_http_status(:not_found)
      expect(AlertSubscription.count).to eq(0)
    end
  end

  it "requires authentication" do
    get new_alert_path
    expect(response).to redirect_to(new_session_path(locale: I18n.locale))

    post alerts_path, params: { alert: form_params }
    expect(response).to redirect_to(new_session_path(locale: I18n.locale))
    expect(Alert.count).to eq(0)
  end
end
