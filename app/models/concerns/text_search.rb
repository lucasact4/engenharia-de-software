module TextSearch
  extend ActiveSupport::Concern

  class_methods do
    # A busca parcial lê somente registros no escopo autorizado, em lotes.
    def search_encrypted(term, *fields)
      filter_decrypted(term, *fields) { |record| fields.map { |field| record.public_send(field) } }
    end

    def filter_decrypted(term, *fields)
      term = term.to_s.strip.first(100).downcase
      return all if term.empty?

      records = fields.empty? ? all : select(arel_table[primary_key], *fields.map { |field| arel_table[field] })
      ids = records.find_each.filter_map do |record|
        record.id if yield(record).compact.any? { |value| value.to_s.downcase.include?(term) }
      end
      where(primary_key => ids)
    end

  end
end
