# Busca textual simples para SQLite. LOWER() e LIKE do SQLite só ignoram caixa em ASCII
# ("Árvore" não casa com "árvore"), por isso o termo é testado em algumas variantes de caixa.
module TextSearch
  extend ActiveSupport::Concern

  class_methods do
    def text_search(term, *columns)
      term = term.to_s.strip.first(100)
      return all if term.blank?

      variants = [ term, term.downcase, term.upcase, term.capitalize ].uniq
      clauses = columns.product(variants).map { |column, _| "#{column} LIKE ? ESCAPE '\\'" }
      values = columns.product(variants).map { |_, variant| "%#{sanitize_sql_like(variant)}%" }
      where(clauses.join(" OR "), *values)
    end
  end
end
