module Smoke
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

    # characters that json encoders escape differently: html entities, a line separator, non-ascii.
    def awkward
      expose :html => %(<a href="x">Tom & Jerry's</a>), :separator => "a b", :accent => "café"
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
end
