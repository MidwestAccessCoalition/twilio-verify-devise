require "rails/generators"

module TwilioVerifyDevise
  module Generators
    # Install Generator
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      class_option :haml, :type => :boolean, :required => false, :default => false, :desc => "Generate views in Haml"
      class_option :sass, :type => :boolean, :required => false, :default => false, :desc => "Generate stylesheet in Sass"

      desc "Install the devise authy extension"

      def add_configs
        inject_into_file "config/initializers/devise.rb", "\n" +
        "  # ==> Devise Authy Authentication Extension\n" +
        "  # How long should the user's device be remembered for.\n" +
        "  # config.authy_remember_device = 1.month\n\n" +
        "  # Should Authy OneTouch be enabled?\n" +
        "  # config.authy_enable_onetouch = false\n\n" +
        "  # Should generating QR codes for other authenticator apps be enabled?\n" +
        "  # Note: you need to enable this in your Twilio console.\n" +
        "  # config.authy_enable_qr_code = false\n\n", :after => "Devise.setup do |config|\n"
      end

      def add_initializer
        initializer("authy.rb") do
          "Authy.api_key = ENV[\"AUTHY_API_KEY\"]\n" \
          "Authy.api_uri = \"https://api.authy.com/\""
        end
      end

      def copy_locale
        copy_file "../../../config/locales/en.yml", "config/locales/devise.authy.en.yml"
      end

      def copy_views
        if options.haml?
          copy_file '../../../app/views/devise/enable_twilio_verify.html.haml', 'app/views/devise/devise_authy/enable_twilio_verify.html.haml'
          copy_file '../../../app/views/devise/verify_twilio_verify.html.haml', 'app/views/devise/devise_authy/verify_twilio_verify.html.haml'
          copy_file '../../../app/views/devise/verify_twilio_verify_installation.html.haml', 'app/views/devise/devise_authy/verify_twilio_verify_installation.html.haml'
        else
          copy_file '../../../app/views/devise/enable_twilio_verify.html.erb', 'app/views/devise/devise_authy/enable_twilio_verify.html.erb'
          copy_file '../../../app/views/devise/verify_twilio_verify.html.erb', 'app/views/devise/devise_authy/verify_twilio_verify.html.erb'
          copy_file '../../../app/views/devise/verify_twilio_verify_installation.html.erb', 'app/views/devise/devise_authy/verify_twilio_verify_installation.html.erb'
        end
      end

      def copy_assets
        if options.sass?
          copy_file '../../../app/assets/stylesheets/devise_authy.sass', 'app/assets/stylesheets/devise_authy.sass'
        else
          copy_file '../../../app/assets/stylesheets/devise_authy.css', 'app/assets/stylesheets/devise_authy.css'
        end
        copy_file '../../../app/assets/javascripts/devise_authy.js', 'app/assets/javascripts/devise_authy.js'
      end

      def inject_assets_in_layout
        {
          :haml => {
            :before => %r{%body\s*$},
            :content => %@
    =javascript_include_tag "https://www.authy.com/form.authy.min.js"
    =stylesheet_link_tag "https://www.authy.com/form.authy.min.css"
@
          },
          :erb => {
            :before => %r{\s*<\/\s*head\s*>\s*},
            :content => %@
  <%=javascript_include_tag "https://www.authy.com/form.authy.min.js" %>
  <%=stylesheet_link_tag "https://www.authy.com/form.authy.min.css" %>
@
          }
        }.each do |extension, opts|
          file_path = File.join(destination_root, "app", "views", "layouts", "application.html.#{extension}")
          if File.exist?(file_path) && !File.read(file_path).include?("form.authy.min.js")
            inject_into_file(file_path, opts.delete(:content), opts)
          end
        end
      end
    end
  end
end
