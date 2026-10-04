module Users
  # Atualiza os campos de perfil. A própria pessoa decide o opt-in público; a administração
  # pode corrigir nome, usuário e apresentação e retirar o perfil do ar, mas nunca torná-lo
  # público em nome de alguém. E-mail, senha, admin, papéis e desativação têm fluxos próprios.
  class UpdateProfile < ApplicationService
    PERMITTED = %i[display_name username bio public_profile avatar].freeze

    attr_reader :actor

    def initialize(actor:, user:, attributes:, reason: nil)
      @actor = actor
      @user = user
      @attributes = attributes.to_h.symbolize_keys.slice(*PERMITTED)
      @reason = reason
    end

    def call
      own = own_profile?
      authorize!(@user, :update?, policy_class: own ? ProfilePolicy : UserPolicy)
      @attributes.delete(:avatar) if @attributes[:avatar].blank?
      @attributes.delete(:avatar) unless own
      @user.assign_attributes(@attributes)
      if !own && @user.public_profile? && !@user.public_profile_in_database
        @user.errors.add(:public_profile, :opt_in_only)
        raise ActiveRecord::RecordInvalid, @user
      end

      fields = @user.changed & PERMITTED.map(&:to_s)
      fields << "avatar" if @user.attachment_changes["avatar"]
      return @user if fields.empty?

      User.transaction do
        @user.save!
        AuditEvent.record!(actor: actor, action: "user.profile_updated", subject: @user,
                           reason: @reason, metadata: { fields: fields })
      end
      @user
    end

    private

      def own_profile?
        actor.present? && actor.id == @user.id
      end
  end
end
