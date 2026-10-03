module Users
  # O cadastro só concede o papel público escolhido; a liberação provisória não verifica o e-mail.
  class Register
    def self.call(registration:)
      registration.validate!
      role = Role.active.find_by(code: registration.role_code)
      unless role
        registration.errors.add(:role_code, "não está disponível para cadastro")
        raise ActiveModel::ValidationError, registration
      end

      approved = Rails.configuration.x.registration.auto_approve
      User.transaction do
        user = User.new(display_name: registration.display_name, email_address: registration.normalized_email,
                        password: registration.password, password_confirmation: registration.password_confirmation,
                        admin: false, public_profile: false, registration_role_code: role.code,
                        registration_status: approved ? "approved" : "pending",
                        registration_reviewed_at: approved ? Time.current : nil)
        user.save!(context: :registration)
        user.user_roles.create!(role: role)
        AuditEvent.record!(actor: user, action: "user.registered", subject: user,
                           metadata: { role_code: role.code, decision: approved ? "automatic_approval" : "pending" })
        user
      end
    end
  end
end
