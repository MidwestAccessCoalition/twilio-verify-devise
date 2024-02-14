require 'active_support/concern'
require 'active_support/core_ext/integer/time'
require 'devise'
require 'authy'
require_relative './twilio-verify-client'

module Devise
  mattr_accessor :authy_remember_device, :authy_enable_onetouch, :authy_enable_qr_code
  @@authy_remember_device = 1.month
  @@authy_enable_onetouch = false
  @@authy_enable_qr_code = false
end

module DeviseAuthy
  autoload :Mapping, 'devise-authy/mapping'

  module Controllers
    autoload :Passwords, 'devise-authy/controllers/passwords'
    autoload :Helpers, 'devise-authy/controllers/helpers'
  end

  module Views
    autoload :Helpers, 'devise-authy/controllers/view_helpers'
  end
end

require 'devise-authy/routes'
require 'devise-authy/rails'
require 'devise-authy/models/authy_authenticatable'
require 'devise-authy/models/authy_lockable'
require 'devise-authy/version'

Authy.user_agent = "DeviseAuthy/#{DeviseAuthy::VERSION} - #{Authy.user_agent}"

Devise.add_module :authy_authenticatable, :model => 'devise-authy/models/authy_authenticatable', :controller => :devise_authy, :route => :authy
Devise.add_module :authy_lockable,        :model => 'devise-authy/models/authy_lockable'

warn "DEPRECATION WARNING: The authy-devise library is no longer actively maintained. The Authy API is being replaced by the Twilio Verify API. Please see the README for more details."