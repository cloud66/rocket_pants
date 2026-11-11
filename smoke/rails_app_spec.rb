require_relative 'smoke_helper'
require 'rake'

# bodies are asserted as exact strings on purpose: the envelope is a contract with api clients,
# and the same strings must come out of every supported rails version.
describe 'rocket_pants inside a real Rails application' do

  describe 'booting through the railtie' do

    it 'should insert the cache middleware directly before Rack::Runtime' do
      names = Rails.application.middleware.map(&:name)
      names.should include 'RocketPants::CacheMiddleware'
      names.index('RocketPants::CacheMiddleware').should == names.index('Rack::Runtime') - 1
    end

    it 'should copy the application configuration across' do
      RocketPants.caching_enabled?.should be true
      RocketPants.pass_through_errors?.should be false
    end

    it 'should give controllers the application logger' do
      RocketPants::Base.logger.should equal Rails.logger
    end

    it 'should include the testing support in the test environment' do
      RocketPants::Base.should include ActionController::Testing
    end

    it 'should have loaded the controllers at boot' do
      Rails.application.config.eager_load.should be true
      Smoke.const_defined?(:WidgetsController, false).should be true
    end

    it 'should draw the api routes without raising a deprecation' do
      paths = Rails.application.routes.routes.map { |route| route.path.spec.to_s }
      paths.should include '/:version/widgets/single(.:format)'
    end

    it 'should list the registered errors from the rake task' do
      Rails.application.load_tasks
      output = StringIO.new
      original, $stdout = $stdout, output
      begin
        Rake::Task['rocket_pants:errors'].invoke
      ensure
        $stdout = original
      end
      output.string.should include 'not_found'
      output.string.should include 'trial_expired'
      output.string.should include '402'
    end

  end

  describe 'exposing data' do

    it 'should wrap a single object' do
      get '/1/widgets/single'
      response.status.should == 200
      response.content_type.should == 'application/json; charset=utf-8'
      response.body.should == %({"response":{"id":1,"name":"anvil"}})
      response.headers['Content-Length'].should == response.body.bytesize.to_s
    end

    it 'should wrap a collection with its count' do
      get '/1/widgets/list'
      response.status.should == 200
      response.body.should == %({"response":[{"id":1},{"id":2}],"count":2})
    end

    it 'should wrap a paginated collection with its pagination' do
      get '/1/widgets/paged'
      response.status.should == 200
      response.body.should == %({"response":[{"id":3},{"id":4}],"count":2,) +
        %("pagination":{"previous":1,"next":3,"current":2,"per_page":2,"count":5,"pages":3}})
    end

    it 'should merge custom metadata into the envelope' do
      get '/1/widgets/with_metadata'
      response.body.should == %({"response":{"id":1},"ok":true})
    end

    it 'should escape awkward characters the same way on every rails version' do
      get '/1/widgets/awkward'
      response.body.should == %q|{"response":{"html":"\u003ca href=\"x\"\u003eTom \u0026 Jerry's\u003c/a\u003e","separator":"a\u2028b","accent":"café"}}|
    end

    it 'should build urls that carry the api version' do
      get '/1/widgets/link'
      json['response']['url'].should == 'http://example.org/1/widgets/single'
    end

    it 'should expose the request id' do
      get '/1/widgets/request_id'
      json['response']['request_id'].should be_present
    end

    it 'should return an empty json response for head' do
      get '/1/widgets/nothing'
      response.status.should == 204
      response.body.should == ''
    end

    it 'should redirect' do
      get '/1/widgets/away'
      response.status.should == 302
      response.headers['Location'].should == 'http://example.org/'
    end

  end

  describe 'versioning' do

    it 'should reject a routable version the controller does not support' do
      get '/2/widgets/single'
      response.status.should == 404
      response.body.should == %({"error":"invalid_version",) +
        %("error_description":"This action is not available in the given version of the api."})
    end

    it 'should not route an unknown version' do
      get '/3/widgets/single'
      response.status.should == 404
      response.content_type.to_s.should_not include 'application/json'
    end

  end

  describe 'errors' do

    it 'should render a built in error' do
      get '/1/widgets/missing'
      response.status.should == 404
      response.content_type.should == 'application/json; charset=utf-8'
      response.body.should == %({"error":"not_found","error_description":"The requested resource could not be found."})
    end

    it 'should render a registered error with its status, message and metadata' do
      get '/1/widgets/expired'
      response.status.should == 402
      response.body.should == %({"error":"trial_expired","error_description":"Your trial has expired.","details":"day 15"})
    end

    it 'should render an unhandled exception as a system error and notify' do
      get '/1/widgets/boom'
      response.status.should == 500
      json['error'].should == 'system'
      SmokeApp::NOTIFIED.map(&:message).should == ['kaboom']
    end

    it 'should map a missing parameter to a bad request' do
      get '/1/widgets/needs_param'
      response.status.should == 400
      # only the name is asserted: rails 8.1 words the underlying message differently from 7.2.
      json['error'].should == 'bad_request'
    end

    it 'should render the same bodies through the internals central calls directly' do
      get '/1/central/missing'
      response.status.should == 404
      response.body.should == %({"error":"not_found","error_description":"The requested resource could not be found."})
      get '/1/central/expired'
      response.status.should == 402
      response.body.should == %({"error":"trial_expired","error_description":"Your trial has expired.","details":"day 15"})
    end

  end

  describe 'http basic authentication' do

    it 'should challenge a request without credentials' do
      get '/1/widgets/secret'
      response.status.should == 401
      response.headers['WWW-Authenticate'].should == 'Basic realm="Smoke"'
    end

    it 'should let valid credentials through' do
      get '/1/widgets/secret', basic_auth('smoke', 'test')
      response.status.should == 200
      response.body.should == %({"response":{"secret":true}})
    end

  end

  describe 'instrumentation' do

    it 'should publish process_action.rocket_pants with the keys central reads' do
      payloads = events_for('process_action.rocket_pants') { get '/1/widgets/single?colour=red' }
      payloads.size.should == 1
      payload = payloads.first
      payload[:controller].should == 'Smoke::WidgetsController'
      payload[:action].should == 'single'
      payload[:method].should == 'GET'
      payload[:path].should == '/1/widgets/single?colour=red'
      payload[:status].should == 200
      payload[:formats].should == [:json]
      payload[:params]['colour'].should == 'red'
      payload[:params]['action'].should == 'single'
      payload[:params]['controller'].should == 'smoke/widgets'
    end

    it 'should publish start_processing.rocket_pants' do
      payloads = events_for('start_processing.rocket_pants') { get '/1/widgets/single' }
      payloads.size.should == 1
      payloads.first[:controller].should == 'Smoke::WidgetsController'
    end

    it 'should report the status of an error response' do
      payloads = events_for('process_action.rocket_pants') { get '/1/widgets/missing' }
      payloads.first[:status].should == 404
    end

    it 'should not publish under the action_controller process_action name' do
      payloads = events_for('process_action.action_controller') { get '/1/widgets/single' }
      payloads.should be_empty
    end

    it 'should log the request through the attached log subscriber' do
      get '/1/widgets/single'
      SmokeApp::LOG.string.should include 'Processing by Smoke::WidgetsController#single'
      SmokeApp::LOG.string.should include 'Completed 200 OK'
      SmokeApp::LOG.string.should_not include 'Could not log'
    end

  end

  describe 'the cache middleware' do

    it 'should pass a request with an unknown etag through' do
      get '/1/widgets/single', 'HTTP_IF_NONE_MATCH' => '"widget:stale"'
      response.status.should == 200
    end

    it 'should answer not modified for a recorded etag' do
      RocketPants.cache['widget'] = 'fresh'
      begin
        get '/1/widgets/single', 'HTTP_IF_NONE_MATCH' => '"widget:fresh"'
        response.status.should == 304
        response.body.should == ''
      ensure
        RocketPants.cache.delete 'widget'
      end
    end

  end

end
