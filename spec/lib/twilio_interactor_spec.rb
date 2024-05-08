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

  describe '#delete_entity' do
    context 'when identity is blank' do
      it 'does not call verify_client.delete_entity' do
        verify_client = double('verify_client')

        expect(verify_client).to_not receive(:delete_entity)

        interactor = TwilioInteractor.new(verify_client)

        expect(interactor.delete_entity(nil)).to be_falsey
      end
    end

    context 'when an error is raised' do
      it 'reraises the error from verify_client.delete_entity' do
        verify_client = double('verify_client')

        expect(verify_client).to receive(:delete_entity).with('an id').and_raise('this is an error')

        interactor = TwilioInteractor.new(verify_client)

        expect { interactor.delete_entity('an id') }.to raise_error(StandardError)
      end
    end

    context 'when an error is raised with a message that includes 20404/already deleted' do
      it "is falsey" do
        verify_client = double('verify_client')

        expect(verify_client).to receive(:delete_entity).with('an id').and_raise("this includes 20404")

        interactor = TwilioInteractor.new(verify_client)

        expect(interactor.delete_entity('an id')).to be_falsey
      end
    end

    context 'when successful' do
      # from docs, it's not clear what is actually returned by deleteentity
      # https://www.twilio.com/docs/verify/api/entity#delete-an-entity-resource
      it 'it is truthy' do 
        verify_client = double('verify_client')

        expect(verify_client).to receive(:delete_entity).with('an id').and_return(true)

        interactor = TwilioInteractor.new(verify_client)

        expect(interactor.delete_entity('an id')).to be_truthy
      end
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

  describe '#totp_registration_valid?' do
    context 'when validate_totp_registration returns verified status' do
      it 'returns true' do
        verify_client = double('verify_client')
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_registration).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_return('verified')

        interactor = TwilioInteractor.new(verify_client)

        expect(interactor.totp_registration_valid?(mfa_config, token)).to eq true
      end
      
    end

    context 'when validate_totp_registration returns a non-verified status' do
      it 'returns false' do
        verify_client = double('verify_client')
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_registration).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_return('not-verified')

        interactor = TwilioInteractor.new(verify_client)

        expect(interactor.totp_registration_valid?(mfa_config, token)).to eq false
      end
    end
    
    context 'when validate_totp_registration raises an error' do
      it 'reraises an error' do
        verify_client = double('verify_client')
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_registration).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_raise('an error!')

        interactor = TwilioInteractor.new(verify_client)

        expect { interactor.totp_registration_valid?(mfa_config, token) }.to raise_error(StandardError)
      end
    end

    context 'when validate_totp_registration raises an error and it has 60306/ input token is too long' do
      it 'returns false' do
        verify_client = double('verify_client')
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_registration).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_raise('an error with 60306')

        interactor = TwilioInteractor.new(verify_client)

        expect(interactor.totp_registration_valid?(mfa_config, token)).to eq false
      end
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