# frozen_string_literal: true

RSpec.describe TwilioInteractor do
  describe '#register_totp', pending: true do
    context 'when register_totp_factor returns a valid factor' do
    end

    context 'when register_totp_factor raises' do
    end

    context 'when update! raises' do
    end
  end

  describe '#delete_entity', pending: true do
    context 'when identity is blank' do
    end

    context 'when an error is raised' do
    end

    context 'when an error is raised with a message that includes 20404/already deleted' do
    end

  end

  describe '#registration_token_valid?', pending: true do
    context 'when totp_registration_valid? is true' do
    end
    
    context 'when sms_token_valid? is true' do
    end

    context 'when neither are true' do
    end
  end

  describe '#totp_registration_valid?', pending: true do
    context 'when validate_totp_registration returns verified status' do
    end

    context 'when validate_totp_registration returns a non-verified status' do
    end
    
    context 'when validate_totp_registration raises an error' do
    end

    context 'when validate_totp_registration raises an error and it has 60306/ input token is too long' do
    end
  end

  describe '#sms_token_valid?', pending: true do
    context 'when check_sms_verification_code returns approved status' do
    end

    context 'when check_sms_verification_code returns a non-approved status' do
    end
    
    context 'when check_sms_verification_code raises an error' do
    end

    context 'when check_sms_verification_code raises an error and it has 20404/ resource does not exist' do
    end

    context 'when check_sms_verification_code raises an error and it has 60200/ token is too long' do
    end
  end

  describe '#login_token_valid?', pending: true do
    context 'when totp_login_valid? is true' do
    end
    
    context 'when sms_token_valid? is true' do
    end

    context 'when neither are true' do
    end
  end

  describe '#totp_login_valid?', pending: true do
    context 'when validate_totp_token returns approved status' do
    end

    context 'when validate_totp_token returns a non-approved status' do
    end
    
    context 'when validate_totp_token raises an error' do
    end

    context 'when validate_totp_token raises an error and it has 60318/ resource does not exist' do
    end

    context 'when validate_totp_token raises an error and it has 20404/ factor exists but wasnt validated during registration' do
    end

    context 'when validate_totp_token raises an error and it has 60200/ token is too long' do
    end
  end
end