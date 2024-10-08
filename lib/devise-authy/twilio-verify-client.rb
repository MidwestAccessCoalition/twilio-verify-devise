# frozen_string_literal: true

require 'twilio-ruby'

# Help: https://www.twilio.com/docs/verify/quickstarts/totp
module DeviseAuthy
  class TwilioVerifyClient
    # For development these values can be found in the Twilio Console at https://console.twilio.com.

    def initialize
      @client = Twilio::REST::Client.new(Devise.twilio_account_sid, Devise.twilio_auth_token)
    end

    #################################
    # TOTP methods
    #################################
    def register_totp_factor(identity, friendly_name)
      @client.verify.v2
             .services(Devise.twilio_service_sid)
             .entities(identity)
             .new_factors
             .create(
               friendly_name: friendly_name,
               factor_type: 'totp'
             )
    end

    def validate_totp_registration(identity, factor_id, code)
      response = @client.verify.v2
                        .services(Devise.twilio_service_sid)
                        .entities(identity)
                        .factors(factor_id)
                        .update(auth_payload: code)
      response.status
    end

    def validate_totp_token(identity, factor_id, code)
      response = @client.verify.v2
                        .services(Devise.twilio_service_sid)
                        .entities(identity)
                        .challenges
                        .create(
                          auth_payload: code,
                          factor_sid: factor_id
                        )
      response.status
    end

    # Returns true if successful.
    def delete_totp_factor(identity, factor_id)
      @client.verify.v2
             .services(Devise.twilio_service_sid)
             .entities(identity)
             .factors(factor_id)
             .delete
    end

    # Returns true if successful.
    def delete_entity(identity)
      @client.verify.v2
             .services(Devise.twilio_service_sid)
             .entities(identity)
             .delete
    end

    #################################
    # SMS methods
    #################################
    def send_sms_verification_code(country_code, phone_number)
      response = @client.verify.v2
                        .services(Devise.twilio_service_sid)
                        .verifications
                        .create(to: "+#{country_code}#{phone_number}", channel: 'sms')
      response.status
    end

    def check_sms_verification_code(country_code, phone_number, code)
      response = @client.verify.v2
                        .services(Devise.twilio_service_sid)
                        .verification_checks
                        .create(to: "+#{country_code}#{phone_number}", code: code)
      response.status
    end

    #################################
    # Call methods
    #################################

    def send_call_verification_code(country_code, phone_number)
      response = @client.verify.v2
                        .services(Devise.twilio_service_sid)
                        .verifications
                        .create(to: "+#{country_code}#{phone_number}", channel: 'call')
      response.status
    end
  end
end
