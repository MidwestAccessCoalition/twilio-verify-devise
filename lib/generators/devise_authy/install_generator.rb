require "rails/generators"

module DeviseAuthy
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
        "  # Should generating QR codes for other authenticator apps be enabled?\n" +
        "  # Note: you need to enable this in your Twilio console.\n" +
        "  # config.authy_enable_qr_code = false\n\n", :after => "Devise.setup do |config|\n"
      end

      def copy_locale
        copy_file "../../../config/locales/en.yml", "config/locales/devise.authy.en.yml"
      end

      def copy_views
        if options.haml?
          copy_file '../../../app/views/devise/enable_authy.html.haml', 'app/views/devise/devise_authy/enable_authy.html.haml'
          copy_file '../../../app/views/devise/verify_authy.html.haml', 'app/views/devise/devise_authy/verify_authy.html.haml'
          copy_file '../../../app/views/devise/verify_authy_installation.html.haml', 'app/views/devise/devise_authy/verify_authy_installation.html.haml'
        else
          copy_file '../../../app/views/devise/enable_authy.html.erb', 'app/views/devise/devise_authy/enable_authy.html.erb'
          copy_file '../../../app/views/devise/verify_authy.html.erb', 'app/views/devise/devise_authy/verify_authy.html.erb'
          copy_file '../../../app/views/devise/verify_authy_installation.html.erb', 'app/views/devise/devise_authy/verify_authy_installation.html.erb'
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
    end
  end
end
