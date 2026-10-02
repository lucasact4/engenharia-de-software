module ContentReports
  # Registra uma denúncia por pessoa e alvo; repetir não duplica nem oculta o conteúdo.
  class Create < ApplicationService
    attr_reader :actor

    def initialize(actor:, target:, reason:, details: nil)
      @actor = actor
      @target = target
      @reason = reason
      @details = details
    end

    def call
      authorize_target!
      attributes = { reporter: actor, publication: (@target if @target.is_a?(Publication)),
                     comment: (@target if @target.is_a?(Comment)) }
      existing = ContentReport.find_by(attributes)
      return existing if existing

      ContentReport.create!(attributes.merge(reason: @reason, details: @details))
    rescue ActiveRecord::RecordNotUnique
      ContentReport.find_by!(attributes)
    end

    private

      def authorize_target!
        case @target
        when Publication then authorize!(@target, :interact?)
        when Comment then authorize!(@target, :report?)
        else raise ArgumentError, "alvo de denúncia inválido"
        end
      end
  end
end
