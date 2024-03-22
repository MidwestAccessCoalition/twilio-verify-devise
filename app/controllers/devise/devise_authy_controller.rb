class Devise::DeviseAuthyController < DeviseController
  

  prepend_before_action :find_resource, :only => [
    :request_phone_call, :request_sms
  ]
  prepend_before_action :find_resource_and_require_password_checked, :only => [
    :GET_verify_authy, :POST_verify_authy, :GET_authy_onetouch_status
  ]

  prepend_before_action :check_resource_has_authy_id, :only => [
    :GET_verify_authy_installation, :POST_verify_authy_installation
  ]

  prepend_before_action :check_resource_not_authy_enabled, :only => [
    :GET_verify_authy_installation, :POST_verify_authy_installation
  ]

  prepend_before_action :authenticate_scope!, :only => [
    :GET_enable_authy, :POST_enable_authy, :GET_verify_authy_installation,
    :POST_verify_authy_installation, :POST_disable_authy
  ]

  before_action :initialize_twilio_verify_client

  include Devise::Controllers::Helpers

  # The verify_authy endpoints are for verification on login. Verification after registration
  # is handled by the verify_installation methods.
  def GET_verify_authy
    render :verify_authy
  end

  # verify 2fa
  def POST_verify_authy
    if login_token_valid?(@resource.mfa_config)
      remember_device(@resource.id) if params[:remember_device].to_i == 1
      remember_user
      record_twilio_authentication
      respond_with resource, location: after_sign_in_path_for(@resource)
    else
      handle_invalid_token :verify_authy, :invalid_token
    end
  end

  # enable 2fa
  def GET_enable_authy
    if resource.authy_id.blank? || !resource.authy_enabled
      render :enable_authy
    else
      set_flash_message(:notice, :already_enabled)
      redirect_to after_authy_enabled_path_for(resource)
    end
  end

  def POST_enable_authy
    @authy_user = Authy::API.register_user(
      :email => resource.email,
      :cellphone => params[:cellphone],
      :country_code => params[:country_code]
    )

    if @authy_user.ok?
      resource.authy_id = @authy_user.id
      if resource.save
        redirect_to [resource_name, :verify_authy_installation] and return
      else
        set_flash_message(:error, :not_enabled)
        redirect_to after_authy_enabled_path_for(resource) and return
      end
    else
      set_flash_message(:error, :not_enabled)
      render :enable_authy
    end
  end

  # Disable 2FA
  def POST_disable_authy
    authy_id = resource.authy_id
    resource.assign_attributes(:authy_enabled => false, :authy_id => nil)
    resource.save(:validate => false)

    other_resource = resource.class.find_by(:authy_id => authy_id)
    if other_resource
      # If another resource has the same authy_id, do not delete the user from
      # the API.
      forget_device
      set_flash_message(:notice, :disabled)
    else
      response = Authy::API.delete_user(:id => authy_id)
      if response.ok?
        forget_device
        set_flash_message(:notice, :disabled)
      else
        # If deleting the user from the API fails, set everything back to what
        # it was before.
        # I'm not sure this is a good idea, but it was existing behaviour.
        # Could be changed in a major version bump.
        resource.assign_attributes(:authy_enabled => true, :authy_id => authy_id)
        resource.save(:validate => false)
        set_flash_message(:error, :not_disabled)
      end
    end
    redirect_to after_authy_disabled_path_for(resource)
  end

  def GET_verify_authy_installation
    if resource_class.authy_enable_qr_code
      response = Authy::API.request_qr_code(id: resource.authy_id)
      @authy_qr_code = response.qr_code
    end
    render :verify_authy_installation
  end

  def POST_verify_authy_installation
    token_valid = registration_token_valid?(resource.mfa_config)

    resource.authy_enabled = token_valid

    if token_valid && resource.save
      remember_device(resource.id) if params[:remember_device].to_i == 1
      record_twilio_authentication
      set_flash_message(:notice, :enabled)
      redirect_to after_authy_verified_path_for(resource)
    else
      handle_invalid_token :verify_authy_installation, :invalid_token
    end
  end

  def GET_authy_onetouch_status
    response = Authy::OneTouch.approval_request_status(:uuid => params[:onetouch_uuid])
    status = response.dig('approval_request', 'status')
    case status
    when 'pending'
      head 202
    when 'approved'
      remember_device(@resource.id) if params[:remember_device].to_i == 1
      remember_user
      record_twilio_authentication
      render json: { redirect: after_sign_in_path_for(@resource) }
    when 'denied'
      head :unauthorized
    else
      head :internal_server_error
    end
  end

  def request_phone_call
    unless @resource
      render :json => { :sent => false, :message => "User couldn't be found." }
      return
    end

    response = Authy::API.request_phone_call(:id => @resource.authy_id, :force => true)
    render :json => { :sent => response.ok?, :message => response.message }
  end

  def request_sms
    unless @resource && @resource.mfa_config
      render json: { sent: false, message: "User couldn't be found." }
      return
    end

    mfa_config = @resource.mfa_config
    status = @verify_client.send_sms_verification_code(mfa_config.country_code, mfa_config.cellphone)

    message = status == 'pending' ? 'Token was sent.' : 'Token failed to send.'
    render json: { sent: status == 'pending', message: message }
  end

  private

  def registration_token_valid?(mfa_config)
    totp_registration_valid?(mfa_config) || sms_token_valid?(mfa_config)
  end

  def totp_registration_valid?(mfa_config)
    begin
      status = @verify_client.validate_totp_registration(
        mfa_config.verify_identity, mfa_config.verify_factor_id, params[:token]
      )
    rescue StandardError => e
      # 60306 means the input token is too long.
      raise e unless e.message.include?('60306')

      status = 'invalid'
    end
    status == 'verified'
  end

  def sms_token_valid?(mfa_config)
    begin
      status = @verify_client.check_sms_verification_code(
        mfa_config.country_code, mfa_config.cellphone, params[:token]
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

  def login_token_valid?(mfa_config)
    totp_login_valid?(mfa_config) || sms_token_valid?(mfa_config)
  end

  def totp_login_valid?(mfa_config)
    begin
      status = @verify_client.validate_totp_token(
        mfa_config.verify_identity, mfa_config.verify_factor_id, params[:token]
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

  def sms_token_valid?(mfa_config)
    begin
      status = @verify_client.check_sms_verification_code(
        mfa_config.country_code, mfa_config.cellphone, params[:token]
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

  def authenticate_scope!
    send(:"authenticate_#{resource_name}!", :force => true)
    self.resource = send("current_#{resource_name}")
    @resource = resource
  end

  def find_resource
    @resource = send("current_#{resource_name}")

    if @resource.nil?
      @resource = resource_class.find_by_id(session["#{resource_name}_id"])
    end
  end

  def find_resource_and_require_password_checked
    find_resource

    if @resource.nil? || session[:"#{resource_name}_password_checked"].to_s != "true"
      redirect_to invalid_resource_path
    end
  end

  def check_resource_has_authy_id
    redirect_to [resource_name, :enable_authy] if !resource.authy_id
  end

  def check_resource_not_authy_enabled
    if resource.authy_id && resource.authy_enabled
      redirect_to after_authy_verified_path_for(resource)
    end
  end

  protected

  def after_authy_enabled_path_for(resource)
    root_path
  end

  def after_authy_verified_path_for(resource)
    after_authy_enabled_path_for(resource)
  end

  def after_authy_disabled_path_for(resource)
    root_path
  end

  def invalid_resource_path
    root_path
  end

  def handle_invalid_token(view, error_message)
    if @resource.respond_to?(:invalid_authy_attempt!) && @resource.invalid_authy_attempt!
      after_account_is_locked
    else
      set_flash_message(:error, error_message)
      render view
    end
  end

  def after_account_is_locked
    sign_out_and_redirect @resource
  end

  def remember_user
    if session.delete("#{resource_name}_remember_me") == true && @resource.respond_to?(:remember_me=)
      @resource.remember_me = true
    end
  end

  def initialize_twilio_verify_client
    @verify_client = TwilioVerifyClient.new
  end
end
