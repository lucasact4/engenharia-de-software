# Perfis da apresentação: necessários em qualquer ambiente; o arquivo não sobrescreve edições.
load Rails.root.join("db/seeds/presentation_profiles.rb")

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
