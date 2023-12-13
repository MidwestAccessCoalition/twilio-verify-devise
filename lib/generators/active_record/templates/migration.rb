class TwilioVerifyDeviseAddTo<%= table_name.camelize %> < ActiveRecord::Migration<%= migration_version %>
  def self.up
    change_table :<%= table_name %> do |t|
      t.string    :authy_id
      t.datetime  :last_sign_in_with_authy
      t.boolean   :authy_enabled, :default => false
    end

    add_index :<%= table_name %>, :authy_id
  end

  def self.down
    change_table :<%= table_name %> do |t|
      t.remove :authy_id, :last_sign_in_with_authy, :authy_enabled
    end
  end
end

