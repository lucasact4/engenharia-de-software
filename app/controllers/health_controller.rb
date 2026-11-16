# RNF006: verificação de saúde para monitoramento externo (UptimeRobot e similares).
# /up (Rails) só confirma que o processo responde; /saude confere banco, fila de jobs e cache.
# Retorna 503 quando algo essencial falha, para o monitor contar a indisponibilidade.
class HealthController < ActionController::Base
  QUEUE_HEARTBEAT = 2.minutes

  def show
    checks = { database: database_ok?, queue: queue_ok?, cache: cache_ok? }
    healthy = checks[:database] && checks[:cache] && checks[:queue] != false
    response.set_header("Cache-Control", "no-store")
    render json: { status: healthy ? "ok" : "degraded", checks: checks, time: Time.current.iso8601 },
           status: healthy ? :ok : :service_unavailable
  end

  private

    def database_ok?
      ActiveRecord::Base.connection.select_value("SELECT 1").to_i == 1
    rescue StandardError
      false
    end

    # Sem Solid Queue (ex.: testes), a fila não se aplica e aparece como nil.
    def queue_ok?
      return nil unless defined?(SolidQueue::Process) && ActiveJob::Base.queue_adapter_name.to_s == "solid_queue"

      SolidQueue::Process.where(last_heartbeat_at: QUEUE_HEARTBEAT.ago..).exists?
    rescue StandardError
      false
    end

    def cache_ok?
      key = "health:#{SecureRandom.hex(4)}"
      Rails.cache.write(key, "ok", expires_in: 10.seconds) && Rails.cache.read(key) == "ok"
    rescue StandardError
      false
    ensure
      Rails.cache.delete(key) if key
    end
end
