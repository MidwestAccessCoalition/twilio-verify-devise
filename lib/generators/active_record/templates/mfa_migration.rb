class MfaConfigCreate < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :mfa_configs do |t|
      t.references :<%= table_name %>, null: false, foreign_key: true
      t.string :verify_identity
      t.string :verify_factor_id
      t.string :qr_code_uri
      t.string :cellphone
      t.string :country_code

      t.timestamps
    end
  end
end

