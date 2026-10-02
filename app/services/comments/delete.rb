module Comments
  # Apaga logicamente o comentário do autor, preservando suas respostas.
  class Delete < ApplicationService
    attr_reader :actor

    def initialize(actor:, comment:)
      @actor = actor
      @comment = comment
    end

    def call
      authorize!(@comment, :destroy?)
      @comment.update!(deleted_at: Time.current)
      @comment
    end
  end
end
