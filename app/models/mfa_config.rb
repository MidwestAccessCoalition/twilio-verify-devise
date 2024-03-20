# frozen_string_literal: true

# Multi Factor Authentication (MFA) configuration for a user.
class MfaConfig < ActiveRecord::Base
  belongs_to :resource, polymorphic: true

  before_validation :cellphone

  def format_cellphone
    cellphone&.gsub!(/\D/, '')
  end
end
