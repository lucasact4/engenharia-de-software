class EncryptExistingSguUploads < ActiveRecord::Migration[8.1]
  def up
    ActiveStorage::Blob.find_each do |blob|
      service = blob.service
      next unless service.respond_to?(:migrate_file)

      service.migrate_file(blob.key, checksum: blob.checksum)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Recuperar os anexos cifrados requer as chaves do SGU"
  end
end
