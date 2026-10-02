# frozen_string_literal: true

namespace :sgu do
  namespace :catalogs do
    desc "Cria papéis e categorias essenciais ausentes (idempotente; não altera contas nem nomes editados)"
    task bootstrap: :environment do
      result = Catalogs::Bootstrap.call
      puts "Catálogos: #{result[:roles]} papel(is) e #{result[:categories]} categoria(s) criados."
    end
  end

  namespace :presentation do
    desc "Cria os perfis iniciais da apresentação ausentes (idempotente; não altera perfis editados)"
    task profiles: :environment do
      before = PresentationProfile.count
      load Rails.root.join("db/seeds/presentation_profiles.rb")
      puts "Perfis da apresentação: #{PresentationProfile.count - before} criado(s); #{PresentationProfile.count} no total."
    end
  end
end
