require 'devise-authy/hooks/authy_authenticatable'
module Devise
  module Models
    module AuthyAuthenticatable
      extend ActiveSupport::Concern

      included do
        has_one :mfa_config, as: :resource
      end

      def with_authy_authentication?(request)
        if self.authy_id.present? && self.authy_enabled
          return true
        end

        return false
      end

      module ClassMethods
        def find_by_authy_id(authy_id)
          where(authy_id: authy_id).first
        end

        Devise::Models.config(self, :authy_remember_device, :authy_enable_qr_code)
      end
    end
  end
end

