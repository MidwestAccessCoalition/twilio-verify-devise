require 'active_support/concern'
require 'active_support/core_ext/integer/time'
require 'devise'
require 'authy'

module Devise
  mattr_accessor :authy_remember_device, :authy_enable_onetouch, :authy_enable_qr_code
  @@authy_remember_device = 1.month
  @@authy_enable_onetouch = false
  @@authy_enable_qr_code = false
end

module TwilioVerifyDevise
  autoload :Mapping, 'twilio-verify-devise/mapping'

  module Controllers
    autoload :Passwords, 'twilio-verify-devise/controllers/passwords'
    autoload :Helpers, 'twilio-verify-devise/controllers/helpers'
  end

  module Views
    autoload :Helpers, 'twilio-verify-devise/controllers/view_helpers'
  end
end

require 'twilio-verify-devise/client'
require 'twilio-verify-devise/routes'
require 'twilio-verify-devise/rails'
require 'twilio-verify-devise/models/authy_authenticatable'
require 'twilio-verify-devise/models/authy_lockable'
require 'twilio-verify-devise/version'

Authy.user_agent = "TwilioVerifyDevise/#{TwilioVerifyDevise::VERSION} - #{Authy.user_agent}"

Devise.add_module :authy_authenticatable, :model => 'twilio-verify-devise/models/authy_authenticatable', :controller => :twilio_verify_devise, :route => :authy
Devise.add_module :authy_lockable,        :model => 'twilio-verify-devise/models/authy_lockable'

warn "DEPRECATION WARNING: The authy-devise library is no longer actively maintained. The Authy API is being replaced by the Twilio Verify API. Please see the README for more details."