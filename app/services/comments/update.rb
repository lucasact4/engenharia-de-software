module Comments
  # Edição do texto pelo autor enquanto ele ainda tem acesso à publicação.
  class Update < ApplicationService
    attr_reader :actor

    def initialize(actor:, comment:, body:, lock_version: nil)
      @actor = actor
      @comment = comment
      @body = body
      @lock_version = lock_version
    end

    def call
      authorize!(@comment, :update?)
      apply_lock_version(@comment, @lock_version)
      @comment.body = @body
      return @comment unless @comment.body_changed?

      @comment.edited_at = Time.current
      @comment.save!
      @comment
    end
  end
end
