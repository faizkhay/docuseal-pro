# frozen_string_literal: true

module Billing
  # An account's subscription, stored as the JSON value of its `plan`
  # AccountConfig row. Accounts with no row are treated as being on the default
  # plan rather than as an error state, so existing accounts keep working.
  class Subscription
    ACTIVE_STATUSES = %w[active trialing].freeze

    attr_reader :account, :attributes

    def self.for(account)
      config = AccountConfig.find_by(account:, key: AccountConfig::PLAN_KEY)

      new(account, config&.value)
    end

    # Writes the subscription. `external_id` is whatever the provider calls its
    # subscription; it is what a real webhook would arrive keyed on.
    def self.assign!(account:, plan_id:, status: 'active', external_id: nil, period_end: nil)
      raise ArgumentError, "unknown plan: #{plan_id}" unless Billing.plan?(plan_id)

      config = AccountConfig.find_or_initialize_by(account:, key: AccountConfig::PLAN_KEY)

      config.value = {
        'plan_id' => plan_id.to_s,
        'status' => status.to_s,
        'provider' => Billing.provider.name,
        'external_id' => external_id,
        'current_period_end' => period_end&.iso8601,
        'updated_at' => Time.current.iso8601
      }

      config.save!

      new(account, config.value)
    end

    def initialize(account, attributes = nil)
      @account = account
      @attributes = attributes.presence || {}
    end

    def plan_id
      attributes['plan_id'].presence || Billing::DEFAULT_PLAN_ID
    end

    def plan
      Billing.plan(plan_id) || Billing.default_plan
    end

    def title
      plan[:title]
    end

    def status
      attributes['status'].presence || 'active'
    end

    def active?
      status.in?(ACTIVE_STATUSES)
    end

    def provider_name
      attributes['provider']
    end

    def external_id
      attributes['external_id']
    end

    def current_period_end
      value = attributes['current_period_end']

      Time.zone.parse(value) if value.present?
    end

    def documents_limit
      plan[:documents_per_month]
    end

    def users_limit
      plan[:users]
    end
  end
end
