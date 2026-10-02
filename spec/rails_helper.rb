# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
# Evita truncar dados de produção durante os testes.
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'spec_helper'
require 'rspec/rails'

require 'pundit/rspec'
require 'pundit/matchers'

require 'support/auth_support'
require 'support/selectors_support'
require 'support/pundit_support'
require 'support/policy_examples'
require 'support/sgu_support'

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include PunditSpecHelper, type: :view

  config.include AuthSupport, type: :controller
  config.include AuthSupport, type: :feature
  config.include AuthSupport, type: :view
  config.include AuthSupport, type: :helper
  config.include AuthSupport, type: :request

  # DatabaseCleaner usa transações; testes de navegador exigem truncamento entre exemplos.
  config.use_transactional_fixtures = false

  config.infer_spec_type_from_file_location!

  config.filter_rails_from_backtrace!

  config.before(:suite) do
    DatabaseCleaner.clean_with :truncation
  end

  config.before(:each) do
    Rails.cache.clear
  end

  config.around(:each) do |example|
    DatabaseCleaner.strategy = example.metadata[:type] == :feature ? :truncation : :transaction

    DatabaseCleaner.cleaning do
      I18n.with_locale(I18n.default_locale) { example.run }
    end
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec

    with.library :active_record
    with.library :active_model
  end
end
