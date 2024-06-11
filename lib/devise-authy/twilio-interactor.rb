module DeviseAuthy
class TwilioInteractor

  def initialize(verify_client)
    @verify_client = verify_client
  end

  def register_totp(mfa_config)
    identity = SecureRandom.uuid
    friendly_name = 'Twilio Verify Devise TOTP'

    new_factor = @verify_client.register_totp_factor(identity, friendly_name)

    mfa_config.update!(
      verify_identity: new_factor.identity,
      verify_factor_id: new_factor.sid,
      qr_code_uri: new_factor.binding['uri']
    )
  end

  def delete_entity(identity)
    @verify_client.delete_entity(identity) unless identity.blank?
  rescue StandardError => e
    # 20404 means the resource does not exist. This can happen if an old unverified factor has
    # already been cleaned up (i.e. deleted) by Verify.
    raise e unless e.message.include?('20404')
  end

  def registration_token_valid?(mfa_config, token)
    totp_registration_valid?(mfa_config, token) || sms_token_valid?(mfa_config, token)
  end

  def totp_registration_valid?(mfa_config, token)
    begin
      status = @verify_client.validate_totp_registration(
        mfa_config.verify_identity, mfa_config.verify_factor_id, token
      )
    rescue StandardError => e
      # 60306 means the input token is too long.
      raise e unless e.message.include?('60306')

      status = 'invalid'
    end
    status == 'verified'
  end

  def sms_token_valid?(mfa_config, token)
    begin
      status = @verify_client.check_sms_verification_code(
        mfa_config.country_code, mfa_config.cellphone, token
      )
    rescue StandardError => e
      # 20404 means the resource does not exist. For SMS verification this happens when the wrong
      # code is entered.
      #
      # 60200 means the input token is too long.
      raise e unless e.message.include?('20404') || e.message.include?('60200')

      status = 'invalid'
    end
    status == 'approved'
  end

  def login_token_valid?(mfa_config, token)
    totp_login_valid?(mfa_config, token) || sms_token_valid?(mfa_config, token)
  end

  def totp_login_valid?(mfa_config, token)
    begin
      status = @verify_client.validate_totp_token(
        mfa_config.verify_identity, mfa_config.verify_factor_id, token
      )
    rescue StandardError => e
      # 20404 means the resource does not exist. This can happen if an old unverified factor is
      # cleaned up (i.e. deleted) by Verify. This is okay since the user can still use SMS.
      #
      # 60318 means the factor exists but cannot be validated because it wasn't verified during
      # registration. This is okay since the user can still use SMS.
      #
      # 60306 means the input token is too long.
      raise e unless e.message.include?('60318') || e.message.include?('60306') ||
                     e.message.include?('20404')

      status = 'invalid'
    end
    status == 'approved'
  end
end
end