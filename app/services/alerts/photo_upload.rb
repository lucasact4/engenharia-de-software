module Alerts
  # Confere assinatura PNG/JPEG. As fotos continuam privadas e os metadados EXIF são preservados.
  module PhotoUpload
    SIGNATURES = {
      "image/png" => "\x89PNG\r\n\x1A\n".b,
      "image/jpeg" => "\xFF\xD8\xFF".b
    }.freeze

    module_function

    def detect(io)
      header = read_header(io)
      SIGNATURES.find { |_type, signature| header.start_with?(signature) }&.first
    end

    # Chamado pela validação do Alert para anexos ainda não enviados ao serviço.
    def validate_pending(alert)
      change = alert.attachment_changes["photos"]
      return unless change

      change.attachables.zip(change.blobs).each do |attachable, blob|
        case attachable
        when ActiveStorage::Blob
          alert.errors.add(:photos, :reused_blob) unless already_attached?(alert, attachable)
        when String
          alert.errors.add(:photos, :reused_blob)
        else
          detected = detect(io_for(attachable))
          if detected.nil? || detected != blob.content_type
            alert.errors.add(:photos, :content_type)
          end
        end
      end
    end

    def already_attached?(alert, blob)
      alert.persisted? &&
        ActiveStorage::Attachment.exists?(record: alert, name: "photos", blob_id: blob.id)
    end

    def io_for(attachable)
      case attachable
      when Hash then attachable.fetch(:io)
      when ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile then attachable.tempfile
      when Pathname then attachable.open
      else attachable
      end
    end

    def read_header(io)
      return "".b unless io.respond_to?(:read)

      io.rewind if io.respond_to?(:rewind)
      header = io.read(8).to_s.b
      io.rewind if io.respond_to?(:rewind)
      header
    end
  end
end
