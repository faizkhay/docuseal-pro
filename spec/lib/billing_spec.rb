# frozen_string_literal: true

RSpec.describe Billing do
  let(:account) { create(:account) }

  describe Billing::Subscription do
    it 'treats an account with no plan row as being on the default plan' do
      subscription = described_class.for(account)

      expect(subscription.plan_id).to eq(Billing::DEFAULT_PLAN_ID)
      expect(subscription).to be_active
    end

    it 'refuses an unknown plan' do
      expect { described_class.assign!(account:, plan_id: 'enterprise') }.to raise_error(ArgumentError)
    end

    it 'persists the plan and its provider' do
      described_class.assign!(account:, plan_id: 'pro', external_id: 'sub_123')

      subscription = described_class.for(account.reload)

      expect(subscription.plan_id).to eq('pro')
      expect(subscription.title).to eq('Pro')
      expect(subscription.provider_name).to eq('fake')
      expect(subscription.external_id).to eq('sub_123')
      expect(subscription).to be_active
    end

    it 'exposes limits from the plan catalog' do
      described_class.assign!(account:, plan_id: 'business')

      subscription = described_class.for(account.reload)

      expect(subscription.documents_limit).to be_nil
      expect(subscription.users_limit).to be_nil
    end

    it 'reuses the single plan row rather than adding one per change' do
      described_class.assign!(account:, plan_id: 'pro')

      expect { described_class.assign!(account:, plan_id: 'business') }
        .not_to(change { AccountConfig.where(account:, key: AccountConfig::PLAN_KEY).count })
    end

    it 'is not active once cancelled' do
      described_class.assign!(account:, plan_id: 'pro', status: 'canceled')

      expect(described_class.for(account.reload)).not_to be_active
    end
  end

  describe Billing::FakeProvider do
    let(:provider) { described_class.new }
    let(:other_account) { create(:account) }
    let(:success_url) { 'https://example.com/confirm' }

    def token_from(url)
      Rack::Utils.parse_query(URI.parse(url).query)['token']
    end

    it 'returns a checkout url carrying a token' do
      url = provider.create_checkout_session(account:, plan_id: 'pro', success_url:)

      expect(token_from(url)).to be_present
    end

    it 'preserves query already present on the success url' do
      url = provider.create_checkout_session(account:, plan_id: 'pro',
                                             success_url: "#{success_url}?keep=1")
      query = Rack::Utils.parse_query(URI.parse(url).query)

      expect(query['keep']).to eq('1')
      expect(query['token']).to be_present
    end

    it 'accepts a token it issued for the account' do
      url = provider.create_checkout_session(account:, plan_id: 'pro', success_url:)

      expect(provider.verify_checkout_token(token_from(url), account:)).to include('plan_id' => 'pro')
    end

    # The signature is the trust boundary a real integration will rely on, so a
    # token minted for someone else must not upgrade this account.
    it 'rejects a token issued for a different account' do
      url = provider.create_checkout_session(account: other_account, plan_id: 'business', success_url:)

      expect(provider.verify_checkout_token(token_from(url), account:)).to be_nil
    end

    it 'rejects a forged token' do
      expect(provider.verify_checkout_token('not-a-real-token', account:)).to be_nil
      expect(provider.verify_checkout_token(nil, account:)).to be_nil
    end

    it 'rejects an expired token' do
      url = provider.create_checkout_session(account:, plan_id: 'pro', success_url:)
      token = token_from(url)

      travel(described_class::TOKEN_TTL + 1.minute) do
        expect(provider.verify_checkout_token(token, account:)).to be_nil
      end
    end
  end

  describe '.price' do
    it 'renders free and paid plans' do
      expect(described_class.price('free')).to eq(I18n.t('billing_free'))
      expect(described_class.price('pro')).to eq('$29.00')
    end

    it 'treats an unknown plan as free rather than raising' do
      expect(described_class.price('nope')).to eq(I18n.t('billing_free'))
    end
  end

  describe 'authorization' do
    let(:admin) { create(:user, account:, role: User::ADMIN_ROLE) }
    let(:viewer) { create(:user, account:, role: User::VIEWER_ROLE) }

    it 'restricts billing to admins' do
      expect(Ability.new(admin).can?(:manage, :billing)).to be(true)
      expect(Ability.new(viewer).can?(:manage, :billing)).to be(false)
    end
  end
end
