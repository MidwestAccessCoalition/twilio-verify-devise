# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users
  devise_for :lockable_users, # for testing twilio_verify_lockable
    class: 'LockableUser',
    :path_names => {
      :verify_twilio_verify => "/verify-token",
      :enable_twilio_verify => "/enable-two-factor",
      :verify_twilio_verify_installation => "/verify-installation",
      :authy_onetouch_status => "/onetouch-status"
    }
  root 'home#index'
end
