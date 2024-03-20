module Devise

  module Models

    # Handles connecting the MfaConfig to the resource
    module VerifyMfaable

      extend ActiveSupport::Concern


      included do
        has_one :mfa_config, as: :resource
      end

    end

  end

end
