module Comments
  # Cria um comentário ou uma resposta direta na mesma publicação.
  class Create < ApplicationService
    attr_reader :actor

    def initialize(actor:, publication:, body:, parent: nil)
      @actor = actor
      @publication = publication
      @body = body
      @parent = parent
    end

    def call
      authorize!(@publication, :comment?)
      comment = Comment.new(publication: @publication, author: actor, parent: @parent, body: @body)
      @parent.reload if @parent&.persisted?
      if @parent&.hidden?
        comment.errors.add(:parent, :hidden)
        raise ActiveRecord::RecordInvalid, comment
      end

      comment.save!
      comment
    end
  end
end
