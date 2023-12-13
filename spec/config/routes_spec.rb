# frozen_string_literal: true

RSpec.describe "routes with twilio_verify_devise", type: :controller do
  describe "with default devise_for" do
    it "route to twilio_verify_devise#GET_verify_twilio_verify" do
      expect(get: '/users/verify_twilio_verify').to route_to("devise/twilio_verify_devise#GET_verify_twilio_verify")
    end

    it "routes to twilio_verify_devise#POST_verify_twilio_verify" do
      expect(post: '/users/verify_twilio_verify').to route_to("devise/twilio_verify_devise#POST_verify_twilio_verify")
    end

    it "routes to twilio_verify_devise#GET_enable_twilio_verify" do
      expect(get: '/users/enable_twilio_verify').to route_to("devise/twilio_verify_devise#GET_enable_twilio_verify")
    end

    it "routes to twilio_verify_devise#POST_enable_twilio_verify" do
      expect(post: '/users/enable_twilio_verify').to route_to("devise/twilio_verify_devise#POST_enable_twilio_verify")
    end

    it "routes to twilio_verify_devise#POST_disable_authy" do
      expect(post: '/users/disable_authy').to route_to("devise/twilio_verify_devise#POST_disable_authy")
    end

    it "route to twilio_verify_devise#GET_verify_twilio_verify_installation" do
      expect(get: '/users/verify_twilio_verify_installation').to route_to("devise/twilio_verify_devise#GET_verify_twilio_verify_installation")
    end

    it "routes to twilio_verify_devise#POST_verify_twilio_verify_installation" do
      expect(post: '/users/verify_twilio_verify_installation').to route_to("devise/twilio_verify_devise#POST_verify_twilio_verify_installation")
    end

    it "routes to twilio_verify_devise#request_sms" do
      expect(post: '/users/request-sms').to route_to("devise/twilio_verify_devise#request_sms")
    end

    it "routes to twilio_verify_devise#request_phone_call" do
      expect(post: '/users/request-phone-call').to route_to("devise/twilio_verify_devise#request_phone_call")
    end

    it "routes to twilio_verify_devise#GET_authy_onetouch_status" do
      expect(get: '/users/authy_onetouch_status').to route_to("devise/twilio_verify_devise#GET_authy_onetouch_status")
    end
  end

  describe "with customised mapping" do
    # See routing in spec/internal/config/routes.rb for the mapping
    it "updates to new routes set in the mapping" do
      expect(get: '/lockable_users/verify-token').to route_to("devise/twilio_verify_devise#GET_verify_twilio_verify")
      expect(post: '/lockable_users/verify-token').to route_to("devise/twilio_verify_devise#POST_verify_twilio_verify")
      expect(get: '/lockable_users/enable-two-factor').to route_to("devise/twilio_verify_devise#GET_enable_twilio_verify")
      expect(post: '/lockable_users/enable-two-factor').to route_to("devise/twilio_verify_devise#POST_enable_twilio_verify")
      expect(get: '/lockable_users/verify-installation').to route_to("devise/twilio_verify_devise#GET_verify_twilio_verify_installation")
      expect(post: '/lockable_users/verify-installation').to route_to("devise/twilio_verify_devise#POST_verify_twilio_verify_installation")
      expect(get: '/lockable_users/onetouch-status').to route_to("devise/twilio_verify_devise#GET_authy_onetouch_status")
    end

    it "doesn't change routes not in custom mapping" do
      expect(post: '/lockable_users/disable_authy').to route_to("devise/twilio_verify_devise#POST_disable_authy")
      expect(post: '/lockable_users/request-sms').to route_to("devise/twilio_verify_devise#request_sms")
      expect(post: '/lockable_users/request-phone-call').to route_to("devise/twilio_verify_devise#request_phone_call")
    end
  end
end
