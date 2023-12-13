module TwilioVerifyDevise
  class Engine < ::Rails::Engine
    ActiveSupport.on_load(:action_controller) do
      include TwilioVerifyDevise::Controllers::Helpers
    end
    ActiveSupport.on_load(:action_view) do
      include TwilioVerifyDevise::Views::Helpers
    end

    # extend mapping with after_initialize because it's not reloaded
    config.after_initialize do
      Devise::Mapping.send :prepend, TwilioVerifyDevise::Mapping
    end
  end
end

