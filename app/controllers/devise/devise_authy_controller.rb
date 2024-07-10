class Devise::DeviseAuthyController < DeviseController
  

  prepend_before_action :find_resource, :only => [
    :request_phone_call, :request_sms
  ]
  prepend_before_action :find_resource_and_require_password_checked, :only => [
    :GET_verify_authy, :POST_verify_authy
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

  attr_reader :twilio_interactor
  delegate :delete_entity, :login_token_valid?, :registration_token_valid?, :register_totp, to: :twilio_interactor, private: true

  include Devise::Controllers::Helpers

  # The verify_authy endpoints are for verification on login. Verification after registration
  # is handled by the verify_installation methods.
  def GET_verify_authy
    render :verify_authy
  end

  # verify 2fa
  def POST_verify_authy
    if login_token_valid?(@resource.mfa_config, params[:token])
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
    begin
      mfa_config = MfaConfig.find_or_initialize_by(resource: resource)
      mfa_config.update!(
        cellphone: params[:cellphone],
        country_code: params[:country_code]
      )

      register_totp(mfa_config) unless mfa_config.verify_identity.present?

      # authy_id must be set for authy-devise gem to recognize that MFA is enabled. The exact value
      # doesn't matter since we're no longer calling Authy. Uses random uuid to ensure uniqueness.
      resource.authy_id = SecureRandom.uuid
      if resource.save
        redirect_to [resource_name, :verify_authy_installation] and return
      else
        set_flash_message(:error, :not_enabled)
        redirect_to after_authy_enabled_path_for(resource) and return
      end
    rescue StandardError => e
      logger.error "Enabling MFA failed: #{e}"
      set_flash_message(:error, :not_enabled)
      render :enable_authy
    end
  end

  # Disables MFA and deletes all MFA config for the resource across all factors.
  def POST_disable_authy
    mfa_config = resource.mfa_config

    begin
      delete_entity(mfa_config.verify_identity)

      MfaConfig.transaction do 
        mfa_config.delete
        resource.assign_attributes(authy_enabled: false, authy_id: nil)
        resource.save(validate: false)
      end

      forget_device
      set_flash_message(:notice, :disabled)
    rescue StandardError => e
      logger.error "Disabling MFA failed: #{e}"
      set_flash_message(:error, :not_disabled)
    end

    redirect_to after_authy_disabled_path_for(resource)
  end

  def GET_verify_authy_installation
    if resource.mfa_config.qr_code_uri
      uri = resource.mfa_config.qr_code_uri
      # from https://gist.github.com/bf4/5188994
      @verify_qr_code = RQRCode::QRCode.new(uri).as_png(size: 200).to_data_url
    end
    render :verify_authy_installation
  end

  def POST_verify_authy_installation
    token_valid = registration_token_valid?(resource.mfa_config, params[:token])

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
    @verify_client = DeviseAuthy::TwilioVerifyClient.new
    @twilio_interactor = DeviseAuthy::TwilioInteractor.new(@verify_client)
  end
end
