# frozen_string_literal: true
require "generators/active_record/twilio_verify_devise_generator"

RSpec.describe ActiveRecord::Generators::TwilioVerifyDeviseGenerator, type: :generator, pending: true do
  destination File.expand_path("../../tmp", __FILE__)

  after(:all) do
    prepare_destination
  end

  before(:all) do
    prepare_destination
    run_generator ["user"]
  end

  it "copies the migration file across" do
    expect(destination_root).to have_structure {
      directory "db" do
        directory "migrate" do
          migration "twilio_verify_devise_add_to_users.rb" do
            contains "TwilioVerifyDeviseAddToUsers"
            contains "ActiveRecord::Migration[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
          end
        end
      end
    }
  end
end