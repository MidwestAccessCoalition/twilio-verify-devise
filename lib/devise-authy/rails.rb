module DeviseAuthy
  class Engine < ::Rails::Engine
    ActiveSupport.on_load(:action_controller) do
      include DeviseAuthy::Controllers::Helpers
    end
    ActiveSupport.on_load(:action_view) do
      include DeviseAuthy::Views::Helpers
    end

    # extend mapping with after_initialize because it's not reloaded
    config.after_initialize do
      Devise::Mapping.send :prepend, DeviseAuthy::Mapping

      # prefill the :twilio_account_sid, :twilio_auth_token, :twilio_service_sid
      
      Devise.twilio_account_sid = ENV['TWILIO_ACCOUNT_SID'] if Devise.twilio_account_sid.nil?
      Devise.twilio_auth_token = ENV['TWILIO_AUTH_TOKEN'] if Devise.twilio_auth_token.nil?
      Devise.twilio_service_sid = ENV['TWILIO_SERVICE_SID'] if Devise.twilio_service_sid.nil?
    end
  end
end

