ENV["RAILS_ENV"] ||= "test"
# Throwaway keys so encrypted columns (Lockbox / Blind Index) work in tests.
ENV["LOCKBOX_MASTER_KEY"] ||= "0" * 64
ENV["BLIND_INDEX_MASTER_KEY"] ||= "1" * 64
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def create_user(email: "user#{SecureRandom.hex(4)}@example.com")
      User.create!(email: email, password: "password123", password_confirmation: "password123")
    end

    def with_env(vars)
      previous = vars.to_h { |key, _| [ key, ENV[key] ] }
      vars.each { |key, value| ENV[key] = value }
      yield
    ensure
      previous.each { |key, value| ENV[key] = value }
    end

    # Replaces an instance method for the duration of the block (minitest/mock is not bundled).
    def with_stubbed_method(klass, name, implementation)
      original = klass.instance_method(name)
      private_method = klass.private_method_defined?(name)
      klass.define_method(name, implementation)
      klass.send(:private, name) if private_method
      yield
    ensure
      klass.define_method(name, original)
      klass.send(:private, name) if private_method
    end

    def signed_nostr_event
      ::JSON.parse(file_fixture("nostr_signed_event.json").read)
    end
  end
end
