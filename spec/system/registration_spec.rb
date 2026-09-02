# frozen_string_literal: true

RSpec.describe 'Self-serve Registration' do
  # An instance is only open to sign-ups once it has been set up, so there is
  # always at least one existing account.
  let!(:existing_account) { create(:account) }
  let!(:existing_user) { create(:user, account: existing_account) }

  let(:form_data) do
    {
      first_name: 'Ada',
      last_name: 'Lovelace',
      email: 'ada@example.com',
      company_name: 'Analytical Engines',
      password: 'password'
    }
  end

  context 'when sign-up is disabled' do
    before do
      allow(Docuseal).to receive(:signup_enabled?).and_return(false)
    end

    it 'redirects to the sign in page' do
      visit new_registration_path

      expect(page).to have_content('Sign In')
    end

    it 'does not link to sign up from the sign in page' do
      visit new_user_session_path

      expect(page).to have_no_link("Don't have an account?")
    end
  end

  context 'when sign-up is enabled' do
    before do
      allow(Docuseal).to receive(:signup_enabled?).and_return(true)

      visit new_registration_path
    end

    it 'shows the registration page' do
      expect(page).to have_content('Create your account')

      ['First name', 'Last name', 'Email', 'Company name', 'Password'].each do |field|
        expect(page).to have_field(field)
      end
    end

    it 'creates a new account and signs the user in' do
      fill_registration_form(form_data)

      expect do
        click_button 'Sign up'
        page.driver.wait_for_network_idle
      end.to change(Account, :count).by(1).and change(User, :count).by(1)

      user = User.order(:id).last

      expect(user.email).to eq(form_data[:email])
      expect(user.first_name).to eq(form_data[:first_name])
      expect(user.role).to eq(User::ADMIN_ROLE)
      expect(user.account.name).to eq(form_data[:company_name])
      expect(user.account).not_to eq(existing_account)
    end

    it 'gives the new account its own e-signing certificate' do
      fill_registration_form(form_data)

      click_button 'Sign up'
      page.driver.wait_for_network_idle

      account = User.order(:id).last.account
      certs = EncryptedConfig.find_by(account:, key: EncryptedConfig::ESIGN_CERTS_KEY)

      expect(certs.value).to be_present
    end

    # The app URL is instance-wide, read from ENV or the first account's config.
    # Writing one per tenant would make the global lookup ambiguous.
    it 'does not write a per-account app url' do
      fill_registration_form(form_data)

      click_button 'Sign up'
      page.driver.wait_for_network_idle

      account = User.order(:id).last.account

      expect(EncryptedConfig.find_by(account:, key: EncryptedConfig::APP_URL_KEY)).to be_nil
    end

    it 'rejects a duplicate email' do
      fill_registration_form(form_data.merge(email: existing_user.email))

      expect do
        click_button 'Sign up'
      end.not_to(change(User, :count))

      expect(page).to have_content('Email has already been taken')
    end

    it 'rejects a short password' do
      fill_registration_form(form_data.merge(password: 'pass'))

      expect do
        click_button 'Sign up'
      end.not_to(change(User, :count))

      expect(page).to have_content('Password is too short (minimum is 6 characters)')
    end

    it 'redirects an already signed in user' do
      sign_in(existing_user)

      visit new_registration_path

      expect(page).to have_content('You are already signed in.')
    end
  end

  private

  def fill_registration_form(form_data)
    fill_in 'First name', with: form_data[:first_name]
    fill_in 'Last name', with: form_data[:last_name]
    fill_in 'Email', with: form_data[:email]
    fill_in 'Company name', with: form_data[:company_name]
    fill_in 'Password', with: form_data[:password]
  end
end
