# Catálogos essenciais (papéis e categorias) em todos os ambientes. Idempotente: não altera
# contas, nomes editados nem itens desativados. Também disponível como
# `bin/rails sgu:catalogs:bootstrap`, sem executar o restante deste arquivo.
Catalogs::Bootstrap.call

# Perfis da apresentação em todos os ambientes. Idempotente: cria só os perfis ausentes e não
# altera seleções editadas no admin. Também disponível como `bin/rails sgu:presentation:profiles`.
load Rails.root.join("db/seeds/presentation_profiles.rb")

# Contas de demonstração: somente em development. Atenção: redefinem senha, admin e
# reativam as contas abaixo se já existirem.
return unless Rails.env.development?

[
  { email_address: "test@test.com", password: "test@123", admin: false },
  { email_address: "dev@dev.com", password: "test@123", admin: true }
].each do |attributes|
  user = User.find_or_initialize_by(email_address: attributes[:email_address])
  user.update!(
    password: attributes[:password],
    password_confirmation: attributes[:password],
    admin: attributes[:admin],
    deleted_at: nil
  )
end
