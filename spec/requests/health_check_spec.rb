require "rails_helper"

RSpec.describe "RNF006 — verificação de saúde para monitoramento", type: :request do
  it "responde 200 com banco e cache funcionando, sem exigir login" do
    get health_check_path

    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to include("no-store")
    body = JSON.parse(response.body)
    expect(body).to include("status" => "ok")
    expect(body["checks"]).to include("database" => true, "cache" => true)
  end

  it "responde 503 quando o banco não responde, para o monitor contar a indisponibilidade" do
    allow(ActiveRecord::Base.connection).to receive(:select_value).and_raise(ActiveRecord::ConnectionNotEstablished)

    get health_check_path

    expect(response).to have_http_status(:service_unavailable)
    expect(JSON.parse(response.body)).to include("status" => "degraded")
  end

  it "responde 503 quando a fila de jobs está parada há mais de 2 minutos" do
    allow_any_instance_of(HealthController).to receive(:queue_ok?).and_return(false)

    get health_check_path

    expect(response).to have_http_status(:service_unavailable)
    expect(JSON.parse(response.body)["checks"]).to include("queue" => false)
  end
end
