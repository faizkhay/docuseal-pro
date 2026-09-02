# frozen_string_literal: true

RSpec.describe 'Billing' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:, role: User::ADMIN_ROLE) }

  before do
    allow(Billing).to receive(:enabled?).and_return(true)

    sign_in(user)
  end

  context 'when billing is disabled' do
    before do
      allow(Billing).to receive(:enabled?).and_return(false)
    end

    it 'redirects away from the billing page' do
      visit settings_billing_index_path

      expect(page).to have_no_content('Current plan')
    end
  end

  context 'when viewing the billing page' do
    before do
      visit settings_billing_index_path
    end

    it 'shows every plan' do
      Billing::PLANS.each_value do |plan|
        expect(page).to have_content(plan[:title])
      end
    end

    it 'starts an account on the free plan' do
      within('#plan_free') do
        expect(page).to have_content('Current plan')
      end
    end

    it 'says payments are mocked' do
      expect(page).to have_content('mock mode')
    end
  end

  context 'when choosing a paid plan' do
    before do
      visit settings_billing_index_path
    end

    it 'activates the plan through the mock checkout' do
      within('#plan_pro') { click_button 'Choose plan' }

      page.driver.wait_for_network_idle

      subscription = Billing::Subscription.for(account.reload)

      expect(subscription.plan_id).to eq('pro')
      expect(subscription).to be_active
      expect(subscription.provider_name).to eq('fake')
      expect(subscription.external_id).to be_present
    end

    it 'returns to the free plan when cancelled' do
      Billing::Subscription.assign!(account:, plan_id: 'pro')

      visit settings_billing_index_path

      accept_confirm('Are you sure?') do
        within('#plan_pro') { click_button 'Cancel plan' }
      end

      page.driver.wait_for_network_idle

      expect(Billing::Subscription.for(account.reload).plan_id).to eq(Billing::DEFAULT_PLAN_ID)
    end
  end
end
