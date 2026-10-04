module Alerts
  # Valida o conjunto final e a ordem dos anexos antes de salvar o relato inteiro.
  class PhotoSelection
    attr_reader :removed_ids

    def initialize(alert, uploads:, order:, removed_ids:)
      @alert, @uploads, @submitted_order = alert, uploads, order
      @removed_ids = Array(removed_ids).compact_blank
    end

    def prepare!
      existing = @alert.ordered_photos
      invalid! unless @removed_ids.all? { |id| id.to_s.match?(/\A[1-9]\d*\z/) }
      @removed_ids = @removed_ids.map(&:to_i)
      invalid! unless @removed_ids.uniq == @removed_ids && (@removed_ids - existing.map(&:id)).empty?
      retained = existing.reject { |photo| @removed_ids.include?(photo.id) }
      expected = retained.map { |photo| "existing_#{photo.id}" } + @uploads.each_index.map { |index| "new_#{index}" }
      @order = @submitted_order.nil? ? expected : Array(@submitted_order)
      invalid! unless @order.size == expected.size && @order.uniq.size == @order.size && (@order - expected).empty?
      @changed = @uploads.any? || @removed_ids.any? || @order != expected
      if @uploads.any? || @removed_ids.any?
        @alert.photos = retained.map(&:blob) + @uploads
        @new_blobs = @alert.attachment_changes.fetch("photos").blobs.last(@uploads.size) if @uploads.any?
      end
      self
    end

    def changed? = @changed

    def persist_order!
      return unless changed?

      attached = @alert.photos.to_a
      ids = @order.map do |token|
        type, id = token.split("_", 2)
        type == "existing" ? id.to_i : attached.find { |photo| photo.blob_id == @new_blobs.fetch(id.to_i).id }.id
      end
      @alert.update_columns(photo_order: ids)
    end

    private

      def invalid!
        @alert.errors.add(:photos, "seleção inválida; confira as fotos e tente novamente")
        raise ActiveRecord::RecordInvalid, @alert
      end
  end
end
