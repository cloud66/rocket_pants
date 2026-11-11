module RocketPants
  # jsonp is not supported in this fork: it relied on callbacks removed in rails 5.1,
  # so `jsonp` raises an error that says so instead of an unexplained NoMethodError.
  module JSONP
    extend ActiveSupport::Concern

    module ClassMethods

      # @raise [NotImplementedError] always, naming the controller that called it.
      def jsonp(*)
        raise NotImplementedError, "JSONP is not supported in the cloud66 fork of rocket_pants " \
          "(it has been broken since Rails 5.1). " \
          "Remove the `jsonp` call from #{name || 'this controller'}."
      end

    end

  end
end
