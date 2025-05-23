# frozen_string_literal: true

RSpec.describe Devise::DeviseAuthyController, type: :controller do
  let(:user) { create(:authy_user) }
  before(:each) { request.env["devise.mapping"] = Devise.mappings[:user] }

  describe "first step of authentication not complete" do
    describe "with no user details in the session" do
      describe "#GET_verify_authy" do
        it "should redirect to the root_path" do
          get :GET_verify_authy
          expect(response).to redirect_to(root_path)
        end
      end

      describe "#POST_verify_authy" do
        it "should redirect to the root_path" do
          post :POST_verify_authy
          expect(response).to redirect_to(root_path)
        end

        it "should not verify a token" do
          expect_any_instance_of(DeviseAuthy::TwilioInteractor).not_to receive(:login_token_valid?)
          post :POST_verify_authy
        end
      end
    end

    describe "without checking the password" do
      before(:each) { request.session["user_id"] = user.id }

      describe "#GET_verify_authy" do
        it "should redirect to the root_path" do
          get :GET_verify_authy
          expect(response).to redirect_to(root_path)
        end
      end

      describe "#POST_verify_authy" do
        it "should redirect to the root_path" do
          post :POST_verify_authy
          expect(response).to redirect_to(root_path)
        end

        it "should not verify a token" do
          expect_any_instance_of(DeviseAuthy::TwilioInteractor).not_to receive(:login_token_valid?)
          post :POST_verify_authy
        end
      end

    end
  end

  describe "when the first step of authentication is complete" do
    before do
      request.session["user_id"] = user.id
      request.session["user_password_checked"] = true
    end

    describe "GET #verify_authy" do
      it "Should render the second step of authentication" do
        get :GET_verify_authy
        expect(response).to render_template('verify_authy')
        expect(assigns(:verify_client)).to be_an_instance_of DeviseAuthy::TwilioVerifyClient
      end
    end

    describe "POST #verify_authy" do
      let(:verify_success) { 'approved' }
      let(:verify_failure) { 'invalid' }
      let(:valid_verify_token) { SecureRandom.rand(0..999999).to_s.rjust(6, '0') }
      let(:invalid_verify_token) { SecureRandom.rand(0..999999).to_s.rjust(6, '0') }
      let(:user) { create(:authy_user)}

      describe "with a valid token" do 
        before(:each) {
          expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).to receive(:validate_totp_token).with(
            user.mfa_config.verify_identity,
            user.mfa_config.verify_factor_id,
            valid_verify_token
          ).and_return(verify_success)
        }

        describe "without remembering" do
          before(:each) {
            post :POST_verify_authy, params: { :token => valid_verify_token }
          }

          it "should log the user in" do
            expect(subject.current_user).to eq(user)
            expect(session["user_authy_token_checked"]).to be true
          end

          it "should set the last_sign_in_with_authy field on the user" do
            expect(user.last_sign_in_with_authy).to be_nil
            user.reload
            expect(user.last_sign_in_with_authy).not_to be_nil
            expect(user.last_sign_in_with_authy).to be_within(1).of(Time.zone.now)
          end

          it "should redirect to the root_path and set a flash notice" do
            expect(response).to redirect_to(root_path)
            expect(flash[:notice]).to be_nil # we don't have a default signin message
            expect(flash[:error]).to be nil
          end

          it "should not set a remember_device cookie" do
            expect(cookies["remember_device"]).to be_nil
          end

          it "should not remember the user" do
            user.reload
            expect(user.remember_created_at).to be nil
          end
        end

        describe "and remember device selected" do
          before(:each) {
            post :POST_verify_authy, params: {
              :token => valid_verify_token,
              :remember_device => '1'
            }
          }

          it "should set a signed remember_device cookie" do
            jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
            cookie = jar.signed["remember_device"]
            expect(cookie).not_to be_nil
            parsed_cookie = JSON.parse(cookie)
            expect(parsed_cookie["id"]).to eq(user.id)
          end
        end

        describe "and remember_me in the session" do
          before(:each) do
            request.session["user_remember_me"] = true
            post :POST_verify_authy, params: { :token => valid_verify_token }
          end

          it "should remember the user" do
            user.reload
            expect(user.remember_created_at).to be_within(1).of(Time.zone.now)
          end
        end
      end

      describe "with an invalid token" do
        before(:each) {
          expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).to receive(:validate_totp_token).with(
            user.mfa_config.verify_identity,
            user.mfa_config.verify_factor_id,
            invalid_verify_token
          ).and_return(verify_failure)

          expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).to receive(:check_sms_verification_code).with(
            user.mfa_config.country_code,
            user.mfa_config.cellphone,
            invalid_verify_token
          ).and_return(verify_failure)

          post :POST_verify_authy, params: { :token => invalid_verify_token }
        }

        it "Shouldn't log the user in" do
          expect(subject.current_user).to be nil
        end

        it "should redirect to the verification page" do
          expect(response).to render_template('verify_authy')
        end

        it "should set an error message in the flash" do
          expect(flash[:notice]).to be nil
          expect(flash[:error]).not_to be nil
        end
      end

      describe 'with a lockable user' do
        let(:lockable_user) { create(:lockable_authy_user) }
        before(:all) { Devise.lock_strategy = :failed_attempts }

        before(:each) do
          request.session["user_id"] = lockable_user.id
          request.session["user_password_checked"] = true
        end

        it 'locks the account when failed_attempts exceeds maximum' do
          # this is weird but the problem is that every time the call was made, there would be a new TwilioInteractor
          # so we'd get weird results when trying to count this.
          expect_any_instance_of(Devise::DeviseAuthyController).to receive(:login_token_valid?).exactly(Devise.maximum_attempts).times.with(
            lockable_user.mfa_config,
            invalid_verify_token
          ).and_return(false)

          (Devise.maximum_attempts).times do
            post :POST_verify_authy, params: { token: invalid_verify_token }
          end

          lockable_user.reload
          expect(lockable_user.access_locked?).to be true
        end
      end

      describe 'with a user that is not lockable' do
        it 'does not lock the account when failed_attempts exceeds maximum' do
          request.session['user_id']               = user.id
          request.session['user_password_checked'] = true

          # this is weird but the problem is that every time the call was made, there would be a new TwilioInteractor
          # so we'd get weird results when trying to count this.
          expect_any_instance_of(Devise::DeviseAuthyController).to receive(:login_token_valid?).exactly(Devise.maximum_attempts).times.with(
            user.mfa_config,
            invalid_verify_token
          ).and_return(false)

          Devise.maximum_attempts.times do
            post :POST_verify_authy, params: { token: invalid_verify_token }
          end

          user.reload
          expect(user.locked_at).to be_nil
        end
      end
    end

  end

  describe "enabling/disabling authy" do
    describe "with no-one logged in" do
      it "GET #enable_authy should redirect to sign in" do
        get :GET_enable_authy
        expect(response).to redirect_to(new_user_session_path)
      end

      it "POST #enable_authy should redirect to sign in" do
        post :POST_enable_authy
        expect(response).to redirect_to(new_user_session_path)
      end

      it "GET #verify_authy_installation should redirect to sign in" do
        get :GET_verify_authy_installation
        expect(response).to redirect_to(new_user_session_path)
      end

      it "POST #verify_authy_installation should redirect to sign in" do
        post :POST_verify_authy_installation
        expect(response).to redirect_to(new_user_session_path)
      end

      it "POST #disable_authy should redirect to sign in" do
        post :POST_disable_authy
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe "with a logged in user" do
      before(:each) { sign_in(user) }

      describe "GET #enable_authy" do
        it "should render enable authy view if user isn't enabled" do
          user.update_attribute(:authy_enabled, false)
          get :GET_enable_authy
          expect(response).to render_template("enable_authy")
        end

        it "should render enable authy view if user doens't have an authy_id" do
          user.update_attribute(:authy_id, nil)
          get :GET_enable_authy
          expect(response).to render_template("enable_authy")
        end

        it "should redirect and set flash if authy is enabled" do
          user.update_attribute(:authy_enabled, true)
          get :GET_enable_authy
          expect(response).to redirect_to(root_path)
          expect(flash[:notice]).not_to be nil
        end
      end

      describe "POST #enable_authy" do
        let(:user) { create(:user) }
        let(:cellphone) { '3010008090' }
        let(:country_code) { '57' }

        describe "with a successful creation of MfaConfig" do
          before(:each) do
            expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).to receive(:register_totp_factor)
              .and_return(
                double('new_factor',
                       identity: 'identity',
                       sid: 'sid',
                       binding: { 'uri' => 'uri' })
              )
            post :POST_enable_authy, params: { cellphone: cellphone, country_code: country_code }
          end

          it "save the authy_id to the user" do
            user.reload
            expect(user.authy_id).not_to be nil
          end

          it "should not enable the user yet" do
            user.reload
            expect(user.authy_enabled).to be(false)
          end

          it "should redirect to the verification page" do
            expect(response).to redirect_to(user_verify_authy_installation_path)
          end
        end

        describe "but a user that can't be saved" do
          before(:each) do
            expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).to receive(:register_totp_factor)
              .and_return(
                double('new_factor',
                       identity: 'identity',
                       sid: 'sid',
                       binding: { 'uri' => 'uri' })
              )
            expect(user).to receive(:save).and_return(false)
            expect(subject).to receive(:current_user).at_least(:once).and_return(user)
            post :POST_enable_authy, params: { cellphone: cellphone, country_code: country_code }
          end

          it "should set an error flash" do
            expect(flash[:error]).not_to be nil
          end

          it "should redirect" do
            expect(response).to redirect_to(root_path)
          end
        end

        describe "with an unsuccessful registration to Twilio Verify" do
          before(:each) do
            expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).to receive(:register_totp_factor)
              .and_raise(StandardError)

            post :POST_enable_authy, :params => { :cellphone => cellphone, :country_code => country_code }
          end

          it "does not update the authy_id" do
            old_authy_id = user.authy_id
            user.reload
            expect(user.authy_id).to eq(old_authy_id)
          end

          it "shows an error flash" do
            expect(flash[:error]).to eq("Something went wrong while enabling multi-factor authentication")
          end

          it "renders enable_authy page again" do
            expect(response).to render_template('enable_authy')
          end
        end
      end

      describe "GET verify_authy_installation" do
        describe "with a user that hasn't enabled authy yet" do
          let(:user) { create(:user) }
          before(:each) { sign_in(user) }

          it "should redirect to enable authy" do
            get :GET_verify_authy_installation
            expect(response).to redirect_to user_enable_authy_path
          end
        end

        describe "with a user that has enabled authy" do
          it "should redirect to after authy verified path" do
            get :GET_verify_authy_installation
            expect(response).to redirect_to root_path
          end
        end

        describe "with a user with an authy id without authy enabled" do
          before(:each) { user.update_attribute(:authy_enabled, false) }

          it "should render the authy verification page" do
            get :GET_verify_authy_installation
            expect(response).to render_template('verify_authy_installation')
          end

          describe "with qr codes turned on" do
            before(:each) do
              Devise.authy_enable_qr_code = true
            end

            after(:each) do
              Devise.authy_enable_qr_code = false
            end

            it "should generate a QR code" do

              user.mfa_config.update(qr_code_uri: 'https://example.com/qr.png')

              get :GET_verify_authy_installation
              expect(response).to render_template('verify_authy_installation')
              expect(assigns[:verify_qr_code]).to_not be_nil
            end
          end
        end
      end

      describe "POST verify_authy_installation" do
        let(:token) { "000000" }
        let(:totp_approved_status) { 'verified' }

        describe "with a user without an authy id" do
          let(:user) { create(:user) }
          it "redirects to enable path" do
            post :POST_verify_authy_installation, :params => { :token => token }
            expect(response).to redirect_to(user_enable_authy_path)
          end
        end

        describe "with a user that has an authy id and is enabled" do
          it "redirects to after authy verified path" do
            post :POST_verify_authy_installation, :params => { :token => token }
            expect(response).to redirect_to(root_path)
          end
        end

        describe "with a user that has an authy id but isn't enabled" do
          before(:each) { user.update_attribute(:authy_enabled, false) }

          describe "successful verification" do
            before(:each) do
              expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).to receive(:validate_totp_registration)
                .with(
                  user.mfa_config.verify_identity,
                  user.mfa_config.verify_factor_id,
                  token
                ).and_return(totp_approved_status)
              post :POST_verify_authy_installation, :params => { :token => token, :remember_device => '0' }
            end

            it "should enable authy for user" do
              user.reload
              expect(user.authy_enabled).to be true
            end

            it "should set {resource}_authy_token_checked in the session" do
              expect(session["user_authy_token_checked"]).to be true
            end

            it "should set a flash notice and redirect" do
              expect(response).to redirect_to(root_path)
              expect(flash[:notice]).to eq('Multi-factor authentication was enabled')
            end

            it "should not set a remember_device cookie" do
              expect(cookies["remember_device"]).to be_nil
            end
          end

          describe "successful verification with remember device" do
            before(:each) do
              expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).to receive(:validate_totp_registration)
                .with(
                  user.mfa_config.verify_identity,
                  user.mfa_config.verify_factor_id,
                  token
                ).and_return(totp_approved_status)
              post :POST_verify_authy_installation, :params => { :token => token, :remember_device => '1' }
            end

            it "should enable authy for user" do
              user.reload
              expect(user.authy_enabled).to be true
            end
            it "should set {resource}_authy_token_checked in the session" do
              expect(session["user_authy_token_checked"]).to be true
            end
            it "should set a flash notice and redirect" do
              expect(response).to redirect_to(root_path)
              expect(flash[:notice]).to eq('Multi-factor authentication was enabled')
            end

            it "should set a signed remember_device cookie" do
              jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
              cookie = jar.signed["remember_device"]
              expect(cookie).not_to be_nil
              parsed_cookie = JSON.parse(cookie)
              expect(parsed_cookie["id"]).to eq(user.id)
            end
          end

          describe "unsuccessful verification" do
            let(:totp_invalid_status) { 'invalid' }
            before(:each) do
              expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).to receive(:validate_totp_registration)
                .with(
                  user.mfa_config.verify_identity,
                  user.mfa_config.verify_factor_id,
                  token
                ).and_return(totp_invalid_status)

              expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).to receive(:check_sms_verification_code)
                .with(
                  user.mfa_config.country_code,
                  user.mfa_config.cellphone,
                  token
                ).and_raise(StandardError, '20404')

              post :POST_verify_authy_installation, :params => { :token => token }
            end

            it "should not enable authy for user" do
              user.reload
              expect(user.authy_enabled).to be false
            end

            it "should set an error flash and render verify_authy_installation" do
              expect(response).to render_template('verify_authy_installation')
              expect(flash[:error]).to eq('The entered token is invalid')
            end
          end
        end
      end

      describe "POST disable_authy" do
        describe 'successfully' do
          before(:each) do
            cookies.signed[:remember_device] = {
              value: { expires: Time.now.to_i, id: user.id }.to_json,
              secure: false,
              expires: User.authy_remember_device.from_now
            }
            expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).to receive(:delete_entity)
              .with(user.mfa_config.verify_identity)
              .and_return(true)

            post :POST_disable_authy
          end

          it 'should disable 2FA' do
            user.reload
            expect(user.authy_id).to be nil
            expect(user.authy_enabled).to be false
          end

          it 'should forget the device cookie' do
            expect(response.cookies[:remember_device]).to be nil
          end

          it 'should set a flash notice and redirect' do
            expect(flash.now[:notice]).to eq('Multi-factor authentication was disabled')
            expect(response).to redirect_to(root_path)
          end
        end

        describe 'unsuccessfully' do
          before(:each) do
            cookies.signed[:remember_device] = {
              value: { expires: Time.now.to_i, id: user.id }.to_json,
              secure: false,
              expires: User.authy_remember_device.from_now
            }
            expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).to receive(:delete_entity)
              .with(user.mfa_config.verify_identity)
              .and_raise(StandardError)

            post :POST_disable_authy
          end

          it 'should not disable 2FA' do
            user.reload
            expect(user.authy_id).not_to be nil
            expect(user.authy_enabled).to be true
          end

          it 'should not forget the device cookie' do
            expect(cookies[:remember_device]).not_to be_nil
          end

          it 'should set a flash error and redirect' do
            expect(flash[:error]).to eq('Something went wrong while disabling Multi-factor authentication')
            expect(response).to redirect_to(root_path)
          end
        end

        describe 'unsuccessfully but is inside transaction' do
          before(:each) do
            cookies.signed[:remember_device] = {
              value: { expires: Time.now.to_i, id: user.id }.to_json,
              secure: false,
              expires: User.authy_remember_device.from_now
            }
            expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).to receive(:delete_entity)
              .with(user.mfa_config.verify_identity)
              .and_return(true)

            expect_any_instance_of(User).to receive(:save)
              .and_raise(StandardError)

            post :POST_disable_authy
          end

          it 'should not disable 2FA' do
            user.reload
            expect(user.authy_id).not_to be nil
            expect(user.authy_enabled).to be true
          end

          it 'should not delete the mfa config' do
            expect(user.mfa_config).to_not be nil
          end

          it 'should not forget the device cookie' do
            expect(cookies[:remember_device]).not_to be_nil
          end

          it 'should set a flash error and redirect' do
            expect(flash[:error]).to eq('Something went wrong while disabling Multi-factor authentication')
            expect(response).to redirect_to(root_path)
          end
        end
      end
    end
  end

  describe "requesting authentication tokens" do
    describe "without a user" do
      it "Should not request sms if user couldn't be found" do
        expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).not_to receive(:send_sms_verification_code)

        post :request_sms

        expect(response.media_type).to eq('application/json')
        body = JSON.parse(response.body)
        expect(body['sent']).to be false
        expect(body['message']).to eq("User couldn't be found.")
      end

      it "Should not request a phone call if user couldn't be found" do
        expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).not_to receive(:request_phone_call)

        post :request_phone_call

        expect(response.media_type).to eq('application/json')
        body = JSON.parse(response.body)
        expect(body['sent']).to be false
        expect(body['message']).to eq("User couldn't be found.")
      end
    end

    describe "#request_sms" do
      context 'successfully' do 
        before(:each) do
          expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).to receive(:send_sms_verification_code)
            .with(user.mfa_config.country_code, user.mfa_config.cellphone)
            .and_return('pending')
        end
    
        describe "with a logged in user" do
          before(:each) { sign_in user }

          it "should send an SMS and respond with JSON" do
            post :request_sms
            expect(response.media_type).to eq('application/json')
            body = JSON.parse(response.body)

            expect(body['sent']).to be_truthy
            expect(body['message']).to eq("Token was sent.")
          end
        end

        describe "with a user_id in the session" do
          before(:each) { session["user_id"] = user.id }

          it "should send an SMS and respond with JSON" do
            post :request_sms
            expect(response.media_type).to eq('application/json')
            body = JSON.parse(response.body)

            expect(body['sent']).to be_truthy
            expect(body['message']).to eq("Token was sent.")
          end
        end
      end

      context 'unsuccessfully' do 
        before(:each) do
          expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).to receive(:send_sms_verification_code)
            .with(user.mfa_config.country_code, user.mfa_config.cellphone)
            .and_return('not pending')
        end
    
        describe "with a logged in user" do
          before(:each) { sign_in user }

          it "should send an SMS and respond with JSON" do
            post :request_sms
            expect(response.media_type).to eq('application/json')
            body = JSON.parse(response.body)

            expect(body['sent']).to be_falsey
            expect(body['message']).to eq("Token failed to send.")
          end
        end

        describe "with a user_id in the session" do
          before(:each) { session["user_id"] = user.id }

          it "should send an SMS and respond with JSON" do
            post :request_sms
            expect(response.media_type).to eq('application/json')
            body = JSON.parse(response.body)

            expect(body['sent']).to be_falsey
            expect(body['message']).to eq("Token failed to send.")
          end
        end
      end
    end

    describe "#request_phone_call" do
      context 'successfully' do 
        before(:each) do
          expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).to receive(:send_call_verification_code)
            .with(user.mfa_config.country_code, user.mfa_config.cellphone)
            .and_return('pending')
        end
    
        describe "with a logged in user" do
          before(:each) { sign_in user }

          it "should send an phone call and respond with JSON" do
            post :request_phone_call
            expect(response.media_type).to eq('application/json')
            body = JSON.parse(response.body)

            expect(body['sent']).to be_truthy
            expect(body['message']).to eq("Token was sent.")
          end
        end

        describe "with a user_id in the session" do
          before(:each) { session["user_id"] = user.id }

          it "should send an phone call and respond with JSON" do
            post :request_phone_call
            expect(response.media_type).to eq('application/json')
            body = JSON.parse(response.body)

            expect(body['sent']).to be_truthy
            expect(body['message']).to eq("Token was sent.")
          end
        end
      end

      context 'unsuccessfully' do 
        before(:each) do
          expect_any_instance_of(DeviseAuthy::TwilioVerifyClient).to receive(:send_call_verification_code)
            .with(user.mfa_config.country_code, user.mfa_config.cellphone)
            .and_return('not pending')
        end
    
        describe "with a logged in user" do
          before(:each) { sign_in user }

          it "should send an phone call and respond with JSON" do
            post :request_phone_call
            expect(response.media_type).to eq('application/json')
            body = JSON.parse(response.body)

            expect(body['sent']).to be_falsey
            expect(body['message']).to eq("Token failed to send.")
          end
        end

        describe "with a user_id in the session" do
          before(:each) { session["user_id"] = user.id }

          it "should send an phone call and respond with JSON" do
            post :request_phone_call
            expect(response.media_type).to eq('application/json')
            body = JSON.parse(response.body)

            expect(body['sent']).to be_falsey
            expect(body['message']).to eq("Token failed to send.")
          end
        end
      end
    end
  end
end
