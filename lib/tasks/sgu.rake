# frozen_string_literal: true

namespace :sgu do
  namespace :catalogs do
    desc "Cria papéis e categorias essenciais ausentes (idempotente; não altera contas nem nomes editados)"
    task bootstrap: :environment do
      result = Catalogs::Bootstrap.call
      puts "Catálogos: #{result[:roles]} papel(is) e #{result[:categories]} categoria(s) criados."
    end
  end
end
