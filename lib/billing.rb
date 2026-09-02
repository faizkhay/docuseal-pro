# frozen_string_literal: true

# Subscription plans and the payment provider seam.
#
# The provider is deliberately abstracted: FakeProvider round-trips a checkout
# entirely inside the app so the whole flow can be exercised without Stripe
# credentials. Swapping in Stripe means adding a class that answers the same
# two methods (see FakeProvider) and returning it from .provider — no controller
# or view changes.
module Billing
  DEFAULT_PLAN_ID = 'free'

  # documents_per_month and users are nil for unlimited. Prices are in cents to
  # avoid float rounding, and are what a provider would be told to charge.
  PLANS = {
    'free' => {
      title: 'Free',
      price_cents: 0,
      documents_per_month: 10,
      users: 1
    }.freeze,
    'pro' => {
      title: 'Pro',
      price_cents: 2900,
      documents_per_month: 200,
      users: 5
    }.freeze,
    'business' => {
      title: 'Business',
      price_cents: 9900,
      documents_per_month: nil,
      users: nil
    }.freeze
  }.freeze

  module_function

  def enabled?
    ENV['BILLING_ENABLED'] == 'true'
  end

  def plan_ids
    PLANS.keys
  end

  def plan(plan_id)
    PLANS[plan_id.to_s]
  end

  def plan?(plan_id)
    PLANS.key?(plan_id.to_s)
  end

  def default_plan
    PLANS.fetch(DEFAULT_PLAN_ID)
  end

  # Only the fake provider exists so far. When a real one is added, select on
  # an env var here and keep FakeProvider for development and tests.
  def provider
    FakeProvider.new
  end

  def mock_provider?
    provider.is_a?(FakeProvider)
  end

  def price(plan_id)
    cents = plan(plan_id)&.fetch(:price_cents, 0).to_i

    return I18n.t('billing_free') if cents.zero?

    format('$%.2f', cents / 100.0)
  end
end
