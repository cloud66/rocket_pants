module Smoke
  class BaseController < RocketPants::Base
    version 1

    self.exception_notifier_callback = lambda do |controller, exception, request|
      SmokeApp::NOTIFIED << exception
    end
  end
end
