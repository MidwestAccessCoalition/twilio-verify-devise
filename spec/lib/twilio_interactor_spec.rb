# frozen_string_literal: true

RSpec.describe DeviseAuthy::TwilioInteractor do
  let(:verify_client) { double('verify_client') }
  let(:interactor) { DeviseAuthy::TwilioInteractor.new(verify_client) }

  describe '#register_totp' do
    context 'when register_totp_factor returns a valid factor' do
      it 'updates the mfa_config' do
        mfa_config = create(:mfa_config)
        factor = double('factor', identity: 'an identity', sid: 'a sid', binding: {'uri' => 'https://qrcode_uri'})

        expect(verify_client).to receive(:register_totp_factor).with(
            an_instance_of(String), 
            'Twilio Verify Devise TOTP'
          ).and_return(factor)
        
        expect(interactor.register_totp(mfa_config)).to eq true

        mfa_config.reload

        expect(mfa_config.verify_identity).to eq 'an identity'
        expect(mfa_config.verify_factor_id).to eq 'a sid'
        expect(mfa_config.qr_code_uri).to eq 'https://qrcode_uri'
      end
    end

    context 'when register_totp_factor raises' do
      it 'raises' do
        mfa_config = create(:mfa_config)

        expect(verify_client).to receive(:register_totp_factor).with(
            an_instance_of(String), 
            'Twilio Verify Devise TOTP'
          ).and_raise('an scary error')

        expect { interactor.register_totp(mfa_config) }.to raise_error(StandardError)

        mfa_config.reload

        expect(mfa_config.verify_identity).to_not eq 'an identity'
        expect(mfa_config.verify_factor_id).to_not eq 'a sid'
        expect(mfa_config.qr_code_uri).to_not eq 'https://qrcode_uri'
      end
    end

    context 'when update! raises' do
      it 'raises error' do
        mfa_config = create(:mfa_config)
        factor = double('factor', identity: 'an identity', sid: 'a sid', binding: {'uri' => 'https://qrcode_uri'})

        expect(verify_client).to receive(:register_totp_factor).with(
            an_instance_of(String), 
            'Twilio Verify Devise TOTP'
          ).and_return(factor)

        expect(mfa_config).to receive(:update!).and_raise('an error')

        expect { interactor.register_totp(mfa_config) }.to raise_error('an error')
      end
    end
  end

  describe '#delete_entity' do
    context 'when identity is blank' do
      it 'does not call verify_client.delete_entity' do
        expect(verify_client).to_not receive(:delete_entity)

        expect(interactor.delete_entity(nil)).to be_falsey
      end
    end

    context 'when an error is raised' do
      it 'reraises the error from verify_client.delete_entity' do
        expect(verify_client).to receive(:delete_entity).with('an id').and_raise('this is an error')

        expect { interactor.delete_entity('an id') }.to raise_error(StandardError)
      end
    end

    context 'when an error is raised with a message that includes 20404/already deleted' do
      it "is falsey" do
        expect(verify_client).to receive(:delete_entity).with('an id').and_raise("this includes 20404")

        expect(interactor.delete_entity('an id')).to be_falsey
      end
    end

    context 'when successful' do
      # from docs, it's not clear what is actually returned by deleteentity
      # https://www.twilio.com/docs/verify/api/entity#delete-an-entity-resource
      it 'it is truthy' do
        expect(verify_client).to receive(:delete_entity).with('an id').and_return(true)

        expect(interactor.delete_entity('an id')).to be_truthy
      end
    end

  end

  describe '#registration_token_valid?' do
    context 'when totp_registration_valid? is true' do
      it 'returns true' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_registration).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_return('verified')

        expect(verify_client).to_not receive(:check_sms_verification_code)

        expect(interactor.registration_token_valid?(mfa_config, token)).to eq true
      end
    end
    
    context 'when sms_token_valid? is true' do
      it 'returns true' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_registration).with(
          mfa_config.verify_identity, 
          mfa_config.verify_factor_id,
          token
        ).and_return('not-verified')
      
        expect(verify_client).to receive(:check_sms_verification_code).with(
            mfa_config.country_code, 
            mfa_config.cellphone,
            token
          ).and_return('approved')

        expect(interactor.registration_token_valid?(mfa_config, token)).to eq true
      end
    end

    context 'when neither are true' do
      it 'returns false' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_registration).with(
          mfa_config.verify_identity, 
          mfa_config.verify_factor_id,
          token
        ).and_return('not-verified')
      
        expect(verify_client).to receive(:check_sms_verification_code).with(
            mfa_config.country_code, 
            mfa_config.cellphone,
            token
          ).and_return('not-approved')

        expect(interactor.registration_token_valid?(mfa_config, token)).to eq false
      end
    end
  end

  describe '#totp_registration_valid?' do
    context 'when validate_totp_registration returns verified status' do
      it 'returns true' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_registration).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_return('verified')

        expect(interactor.totp_registration_valid?(mfa_config, token)).to eq true
      end
      
    end

    context 'when validate_totp_registration returns a non-verified status' do
      it 'returns false' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_registration).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_return('not-verified')

        expect(interactor.totp_registration_valid?(mfa_config, token)).to eq false
      end
    end
    
    context 'when validate_totp_registration raises an error' do
      it 'reraises an error' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_registration).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_raise('an error!')

        expect { interactor.totp_registration_valid?(mfa_config, token) }.to raise_error(StandardError)
      end
    end

    context 'when validate_totp_registration raises an error and it has 60306/ input token is too long' do
      it 'returns false' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_registration).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_raise('an error with 60306')

        expect(interactor.totp_registration_valid?(mfa_config, token)).to eq false
      end
    end
  end

  describe '#sms_token_valid?' do
    context 'when check_sms_verification_code returns approved status' do
      it 'returns true' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:check_sms_verification_code).with(
            mfa_config.country_code, 
            mfa_config.cellphone,
            token
          ).and_return('approved')

        expect(interactor.sms_token_valid?(mfa_config, token)).to eq true
      end
    end

    context 'when check_sms_verification_code returns a non-approved status' do
      it 'returns false' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:check_sms_verification_code).with(
            mfa_config.country_code, 
            mfa_config.cellphone,
            token
          ).and_return('not-approved')

        expect(interactor.sms_token_valid?(mfa_config, token)).to eq false
      end
    end
    
    context 'when check_sms_verification_code raises an error' do
      it 'reraises the error' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:check_sms_verification_code).with(
            mfa_config.country_code, 
            mfa_config.cellphone,
            token
          ).and_raise('an error!')

        expect { interactor.sms_token_valid?(mfa_config, token) }.to raise_error(StandardError)
      end
    end

    context 'when check_sms_verification_code raises an error and it has 20404/ resource does not exist' do
      it 'returns false' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:check_sms_verification_code).with(
            mfa_config.country_code, 
            mfa_config.cellphone,
            token
          ).and_raise('an error with 20404')

        expect(interactor.sms_token_valid?(mfa_config, token)).to eq false
      end
    end

    context 'when check_sms_verification_code raises an error and it has 60200/ token is too long' do
      it 'returns false' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:check_sms_verification_code).with(
            mfa_config.country_code, 
            mfa_config.cellphone,
            token
          ).and_raise('an error with 60200')

        expect(interactor.sms_token_valid?(mfa_config, token)).to eq false
      end
    end
  end

  describe '#login_token_valid?' do
    context 'when totp_login_valid? is true' do
      it 'returns true' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_token).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_return('approved')

        expect(verify_client).to_not receive(:check_sms_verification_code)

        expect(interactor.login_token_valid?(mfa_config, token)).to eq true
      end
    end
    
    context 'when sms_token_valid? is true' do
      it 'returns true' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_token).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_return('not-approved')

          expect(verify_client).to receive(:check_sms_verification_code).with(
            mfa_config.country_code, 
            mfa_config.cellphone,
            token
          ).and_return('approved')

        expect(interactor.login_token_valid?(mfa_config, token)).to eq true
      end
    end

    context 'when neither are true' do
      it 'returns false' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_token).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_return('not-approved')

          expect(verify_client).to receive(:check_sms_verification_code).with(
            mfa_config.country_code, 
            mfa_config.cellphone,
            token
          ).and_return('not-approved')

        expect(interactor.login_token_valid?(mfa_config, token)).to eq false
      end
    end
  end

  describe '#totp_login_valid?' do
    context 'when validate_totp_token returns approved status' do
      it 'returns true' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_token).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_return('approved')

        expect(interactor.totp_login_valid?(mfa_config, token)).to eq true
      end
    end

    context 'when validate_totp_token returns a non-approved status' do
      it 'returns false' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_token).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_return('not-approved')

        expect(interactor.totp_login_valid?(mfa_config, token)).to eq false
      end
    end
    
    context 'when validate_totp_token raises an error' do
      it 'reraises the error' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_token).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_raise("a wild error appears!")

        expect { interactor.totp_login_valid?(mfa_config, token) }.to raise_error(StandardError)
      end
    end

    context 'when validate_totp_token raises an error and it has 60318/ resource does not exist' do
      it 'returns false' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_token).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_return('it has  60318 in its error')

        expect(interactor.totp_login_valid?(mfa_config, token)).to eq false
      end
    end

    context 'when validate_totp_token raises an error and it has 20404/ factor exists but wasnt validated during registration' do

      it 'returns false' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_token).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_return('it has  20404 in its error')

        expect(interactor.totp_login_valid?(mfa_config, token)).to eq false
      end
    end

    context 'when validate_totp_token raises an error and it has 60200/ token is too long' do
      it 'returns false' do
        mfa_config = build(:mfa_config)
        token = "token"

        expect(verify_client).to receive(:validate_totp_token).with(
            mfa_config.verify_identity, 
            mfa_config.verify_factor_id,
            token
          ).and_return('it has  60200 in its error')

        expect(interactor.totp_login_valid?(mfa_config, token)).to eq false
      end
    end
  end
end