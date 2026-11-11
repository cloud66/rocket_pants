# boots a real rails application around rocket_pants, in its own process: the main suite
# never loads rails, so the railtie, middleware stack and route loading are only run here.
ENV["RAILS_ENV"] = "test"

require 'bundler/setup'
require 'stringio'
require 'logger'
# rails must be loaded first: rocket_pants only loads its railtie when Rails::Railtie exists.
require 'rails'
require 'action_controller/railtie'
require 'will_paginate/collection'
require 'rocket_pants'

module SmokeApp
  LOG      = StringIO.new
  NOTIFIED = []

  class Application < Rails::Application
    config.root = File.expand_path(__dir__)
    # central stays on the 7.2 defaults while it moves to rails 8.1.
    config.load_defaults 7.2
    # as central does in every environment: controllers and routes load at boot, after
    # deprecations have been set to raise, so a deprecation in a class body fails the boot.
    config.eager_load      = true
    config.secret_key_base = "smoke"
    config.hosts.clear
    config.logger    = ActiveSupport::Logger.new(LOG)
    config.log_level = :debug
    config.active_support.deprecation = :raise
    # rails 8.0 alone warns at boot unless this is set, and 8.1 deprecates the setting itself.
    config.active_support.to_time_preserves_timezone = :zone if Rails.gem_version.segments.first(2) == [8, 0]

    # production values: the railtie only inserts the cache middleware when caching is on.
    config.rocket_pants.use_caching         = true
    config.rocket_pants.pass_through_errors = false
  end

  module Requests
    def app_request
      Rack::MockRequest.new(Rails.application)
    end

    def get(path, env = {})
      @response = app_request.get(path, env)
    end

    def response
      @response
    end

    def json
      ActiveSupport::JSON.decode(response.body)
    end

    def basic_auth(user, password)
      {"HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(user, password)}
    end

    # collects the payloads of every event matching the pattern while the block runs.
    def events_for(pattern)
      payloads = []
      callback = lambda { |*args| payloads << ActiveSupport::Notifications::Event.new(*args).payload }
      ActiveSupport::Notifications.subscribed(callback, pattern) { yield }
      payloads
    end
  end
end

SmokeApp::Application.initialize!

RSpec.configure do |config|
  config.include SmokeApp::Requests

  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.before(:each) do
    SmokeApp::NOTIFIED.clear
    SmokeApp::LOG.truncate(0)
    SmokeApp::LOG.rewind
  end
end
