# Base dos serviços, com autorização explícita do ator e verificação de versão.
class ApplicationService
  def self.call(...)
    new(...).call
  end

  private

    def authorize!(record, query, policy_class: nil)
      Pundit.authorize(actor, record, query, policy_class: policy_class)
    end

    def apply_lock_version(record, lock_version)
      return if lock_version.nil?

      expected_version = Integer(lock_version.to_s, exception: false)
      return if expected_version == record.lock_version

      raise ActiveRecord::StaleObjectError.new(record, "update")
    end

    def require_reason!(reason, record)
      return if reason.to_s.strip.present?

      record.errors.add(:base, :reason_required)
      raise ActiveRecord::RecordInvalid, record
    end
end
