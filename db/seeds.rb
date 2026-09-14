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
