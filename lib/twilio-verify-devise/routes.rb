module ActionDispatch::Routing
  class Mapper
    protected

    # this must be in this order because devise is funky and expects their routes helper to prefix devise. I don't know why.
    def devise_twilio_verify(mapping, controllers) 
      match "/#{mapping.path_names[:verify_twilio_verify]}", :controller => controllers[:twilio_verify_devise], :action => :GET_verify_twilio_verify, :as => :verify_twilio_verify, :via => :get
      match "/#{mapping.path_names[:verify_twilio_verify]}", :controller => controllers[:twilio_verify_devise], :action => :POST_verify_twilio_verify, :as => nil, :via => :post

      match "/#{mapping.path_names[:enable_twilio_verify]}", :controller => controllers[:twilio_verify_devise], :action => :GET_enable_twilio_verify, :as => :enable_twilio_verify, :via => :get
      match "/#{mapping.path_names[:enable_twilio_verify]}", :controller => controllers[:twilio_verify_devise], :action => :POST_enable_twilio_verify, :as => nil, :via => :post

      match "/#{mapping.path_names[:disable_twilio_verify]}", :controller => controllers[:twilio_verify_devise], :action => :POST_disable_twilio_verify, :as => :disable_twilio_verify, :via => :post

      match "/#{mapping.path_names[:verify_twilio_verify_installation]}", :controller => controllers[:twilio_verify_devise], :action => :GET_verify_twilio_verify_installation, :as => :verify_twilio_verify_installation, :via => :get
      match "/#{mapping.path_names[:verify_twilio_verify_installation]}", :controller => controllers[:twilio_verify_devise], :action => :POST_verify_twilio_verify_installation, :as => nil, :via => :post

      match "/#{mapping.path_names[:request_sms]}", :controller => controllers[:twilio_verify_devise], :action => :request_sms, :as => :request_sms, :via => :post
      match "/#{mapping.path_names[:request_phone_call]}", :controller => controllers[:twilio_verify_devise], :action => :request_phone_call, :as => :request_phone_call, :via => :post
    end
  end
end

