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

module Smoke
  LOG      = StringIO.new
  NOTIFIED = []

  class Application < Rails::Application
    config.root = File.expand_path(__dir__)
    # central stays on the 7.2 defaults while it moves to rails 8.1.
    config.load_defaults 7.2
    config.eager_load      = false
    config.secret_key_base = "smoke"
    config.hosts.clear
    config.logger    = ActiveSupport::Logger.new(LOG)
    config.log_level = :debug
    # same setting as central in development and test.
    config.active_support.deprecation = :raise
    # rails 8.0 alone warns at boot unless this is set, and 8.1 deprecates the setting itself.
    config.active_support.to_time_preserves_timezone = :zone if Rails.gem_version.segments.first(2) == [8, 0]

    # production values: the railtie only inserts the cache middleware when caching is on.
    config.rocket_pants.use_caching         = true
    config.rocket_pants.pass_through_errors = false
  end

  RocketPants::Errors.register! :trial_expired, :http_status => 402

  class BaseController < RocketPants::Base
    version 1

    self.exception_notifier_callback = lambda do |controller, exception, request|
      NOTIFIED << exception
    end
  end

  class WidgetsController < BaseController
    before_action :authenticate, :only => :secret

    def single
      expose :id => 1, :name => "anvil"
    end

    def list
      expose [{:id => 1}, {:id => 2}]
    end

    def paged
      page = WillPaginate::Collection.create(2, 2, 5) { |pager| pager.replace [{:id => 3}, {:id => 4}] }
      expose page
    end

    def with_metadata
      expose({:id => 1}, :metadata => {:ok => true})
    end

    def missing
      error! :not_found
    end

    def expired
      error! :trial_expired, "Your trial has expired.", :metadata => {:details => "day 15"}
    end

    def boom
      raise "kaboom"
    end

    def needs_param
      expose :name => params.require(:widget)
    end

    def nothing
      head :no_content
    end

    def link
      expose :url => single_widget_url
    end

    def request_id
      expose :request_id => request.request_id
    end

    def away
      redirect_to "/"
    end

    def secret
      expose :secret => true
    end

    private

    def authenticate
      authenticate_or_request_with_http_basic("Smoke") { |user, password| user == "smoke" && password == "test" }
    end
  end

  # mirrors how central's Api::RocketPantsLogFixController renders errors through gem internals.
  class CentralStyleController < BaseController
    rescue_from RocketPants::Error, :with => :render_rocket_pants_error

    def missing
      error! :not_found
    end

    def expired
      error! :trial_expired, "Your trial has expired.", :metadata => {:details => "day 15"}
    end

    private

    def render_rocket_pants_error(exception)
      normalised_class = exception.class.ancestors.detect do |klass|
        klass < StandardError and error_mapping.has_key?(klass)
      end
      exception = error_mapping[normalised_class].new(exception.message) if normalised_class
      self.status = lookup_error_status(exception)
      result = {
        :error             => lookup_error_name(exception).to_s,
        :error_description => lookup_error_message(exception)
      }
      render_json result.merge(lookup_error_metadata(exception))
    end
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

Smoke::Application.initialize!

RSpec.configure do |config|
  config.include Smoke::Requests

  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.before(:each) do
    Smoke::NOTIFIED.clear
    Smoke::LOG.truncate(0)
    Smoke::LOG.rewind
  end
end
