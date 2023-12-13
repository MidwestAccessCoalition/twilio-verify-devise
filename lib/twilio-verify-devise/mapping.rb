module TwilioVerifyDevise
  module Mapping
    private
    def default_controllers(options)
      options[:controllers] ||= {}
      options[:controllers][:passwords] ||= "twilio_verify_devise/passwords"
      super
    end

    def default_path_names(options)
      options[:path_names] ||= {}
      options[:path_names][:request_sms] ||= 'request-sms'
      options[:path_names][:request_phone_call] ||= 'request-phone-call'
      super
    end
  end
end
