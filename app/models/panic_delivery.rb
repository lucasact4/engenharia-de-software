# RNF001: cada push ou e-mail de emergência entregue ao serviço de envio, com o tempo desde o pedido.
# "sent" significa aceito pelo serviço de push/e-mail; não comprova que a pessoa já viu o aviso.
class PanicDelivery < ApplicationRecord
  CHANNELS = %w[push email].freeze
  STATUSES = %w[sent failed].freeze
  TARGET_MS = 5_000

  belongs_to :alert
  belongs_to :user

  validates :channel, inclusion: { in: CHANNELS }
  validates :status, inclusion: { in: STATUSES }
  validates :latency_ms, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :error_message, length: { maximum: 200 }

  scope :chronological, -> { order(:created_at, :id) }

  def self.record!(alert:, user:, channel:, status: "sent", error: nil)
    latency = ((Time.current - alert.created_at) * 1000).round
    create!(alert: alert, user: user, channel: channel, status: status,
            latency_ms: latency.clamp(0, 2**31 - 1), error_message: error.to_s.truncate(200).presence)
  end

  def sent? = status == "sent"
  def within_target? = sent? && latency_ms <= TARGET_MS
  def seconds = (latency_ms / 1000.0).round(1)
end
