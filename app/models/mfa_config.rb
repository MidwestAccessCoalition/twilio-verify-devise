# frozen_string_literal: true

# Multi Factor Authentication (MFA) configuration for a user.
class MfaConfig < ApplicationRecord
  belongs_to :user

  before_validation :cellphone

  def format_cellphone
    cellphone&.gsub!(/\D/, '')
  end
end