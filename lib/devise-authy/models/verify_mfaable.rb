module Devise

  module Models

    # Handles connecting the MfaConfig to the user
    module VerifyMfaable

      extend ActiveSupport::Concern


      included do
        has_one :mfa_config
      end

    end

  end

end
