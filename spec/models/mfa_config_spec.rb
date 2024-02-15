RSpec.describe MfaConfig, type: :model do
  it { is_expected.to belong_to(:user) }

  it { is_expected.to have_db_column(:verify_identity) }
  it { is_expected.to have_db_column(:verify_factor_id) }
  it { is_expected.to have_db_column(:qr_code_uri) }
  it { is_expected.to have_db_column(:cellphone) }
  it { is_expected.to have_db_column(:country_code) }
end
