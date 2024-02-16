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

  def GET_verify_authy
    if resource_class.authy_enable_onetouch
      approval_request = send_one_touch_request(@resource.authy_id)['approval_request']
      @onetouch_uuid = approval_request['uuid'] if approval_request.present?
    end
    render :verify_authy
  end

  # verify 2fa
  def POST_verify_authy
    token = Authy::API.verify({
      :id => @resource.authy_id,
      :token => params[:token],
      :force => true
    })

    if token.ok?
      remember_device(@resource.id) if params[:remember_device].to_i == 1
      remember_user
      record_authy_authentication
      respond_with resource, :location => after_sign_in_path_for(@resource)
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

  # Disables MFA and deletes all MFA config for the resource across all factors.
  def POST_disable_authy
    mfa_config = resource.mfa_config

    begin
      delete_entity(mfa_config.verify_identity)
      mfa_config.delete
      resource.assign_attributes(authy_enabled: false, authy_id: nil)
      resource.save(validate: false)

      forget_device
      set_flash_message(:notice, :disabled)
    rescue StandardError => e
      logger.error "Disabling MFA failed: #{e}"
      set_flash_message(:error, :not_disabled)
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
    token = Authy::API.verify({
      :id => self.resource.authy_id,
      :token => params[:token],
      :force => true
    })

    self.resource.authy_enabled = token.ok?

    if token.ok? && self.resource.save
      remember_device(@resource.id) if params[:remember_device].to_i == 1
      record_authy_authentication
      set_flash_message(:notice, :enabled)
      redirect_to after_authy_verified_path_for(resource)
    else
      if resource_class.authy_enable_qr_code
        response = Authy::API.request_qr_code(id: resource.authy_id)
        @authy_qr_code = response.qr_code
      end
      handle_invalid_token :verify_authy_installation, :not_enabled
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
      record_authy_authentication
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
    if !@resource
      render :json => {:sent => false, :message => "User couldn't be found."}
      return
    end

    response = Authy::API.request_sms(:id => @resource.authy_id, :force => true)
    render :json => {:sent => response.ok?, :message => response.message}
  end

  private

  def delete_entity(identity)
    @verify_client.delete_entity(identity) unless identity.blank?
  rescue StandardError => e
    # 20404 means the resource does not exist. This can happen if an old unverified factor has
    # already been cleaned up (i.e. deleted) by Verify.
    raise e unless e.message.include?('20404')
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
