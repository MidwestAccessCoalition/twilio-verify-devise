module ActionDispatch::Routing
  class Mapper
    protected

    def devise_authy(mapping, controllers)
      match "/#{mapping.path_names[:verify_twilio_verify]}", :controller => controllers[:devise_authy], :action => :GET_verify_twilio_verify, :as => :verify_twilio_verify, :via => :get
      match "/#{mapping.path_names[:verify_twilio_verify]}", :controller => controllers[:devise_authy], :action => :POST_verify_twilio_verify, :as => nil, :via => :post

      match "/#{mapping.path_names[:enable_twilio_verify]}", :controller => controllers[:devise_authy], :action => :GET_enable_twilio_verify, :as => :enable_twilio_verify, :via => :get
      match "/#{mapping.path_names[:enable_twilio_verify]}", :controller => controllers[:devise_authy], :action => :POST_enable_twilio_verify, :as => nil, :via => :post

      match "/#{mapping.path_names[:disable_authy]}", :controller => controllers[:devise_authy], :action => :POST_disable_authy, :as => :disable_authy, :via => :post

      match "/#{mapping.path_names[:verify_twilio_verify_installation]}", :controller => controllers[:devise_authy], :action => :GET_verify_twilio_verify_installation, :as => :verify_twilio_verify_installation, :via => :get
      match "/#{mapping.path_names[:verify_twilio_verify_installation]}", :controller => controllers[:devise_authy], :action => :POST_verify_twilio_verify_installation, :as => nil, :via => :post

      match "/#{mapping.path_names[:authy_onetouch_status]}", :controller => controllers[:devise_authy], :action => :GET_authy_onetouch_status, as: :authy_onetouch_status, via: :get

      match "/#{mapping.path_names[:request_sms]}", :controller => controllers[:devise_authy], :action => :request_sms, :as => :request_sms, :via => :post
      match "/#{mapping.path_names[:request_phone_call]}", :controller => controllers[:devise_authy], :action => :request_phone_call, :as => :request_phone_call, :via => :post
    end
  end
end

