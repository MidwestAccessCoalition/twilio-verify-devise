# frozen_string_literal: true

module TwilioVerifyDevise
  module Generators
    class TwilioVerifyDeviseGenerator < Rails::Generators::NamedBase
      namespace "twilio_verify_devise"

      desc "Add :twilio_verify_authenticatable directive in the given model, plus accessors. Also generate migration for ActiveRecord"

      def inject_twilio_verify_devise_content
        path = File.join(destination_root, "app", "models", "#{file_path}.rb")
        if File.exist?(path) &&
           !File.read(path).include?("twilio_verify_authenticatable")
          inject_into_file(path,
                           "twilio_verify_authenticatable, :",
                           :after => "devise :")
        end

        if File.exist?(path) &&
           !File.read(path).include?(":authy_id")
          inject_into_file(path,
                           ":authy_id, :last_sign_in_with_authy, ",
                           :after => "attr_accessible ")
        end
      end

      hook_for :orm
    end
  end
end
