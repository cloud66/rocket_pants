module Smoke
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
end
