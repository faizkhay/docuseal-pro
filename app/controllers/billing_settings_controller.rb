# frozen_string_literal: true

class BillingSettingsController < ApplicationController
  before_action :ensure_billing_enabled!
  before_action -> { authorize!(:manage, :billing) }
  before_action :ensure_mock_provider!, only: :confirm
  before_action :load_subscription

  def index
    @plans = Billing::PLANS
  end

  # Hands off to the provider's checkout. With a real provider this leaves the
  # app; with the mock it comes straight back to #confirm carrying a signed
  # token.
  def create
    plan_id = params[:plan_id].to_s

    unless Billing.plan?(plan_id)
      return redirect_to settings_billing_index_path, alert: I18n.t('billing_unknown_plan')
    end

    checkout_url = Billing.provider.create_checkout_session(
      account: current_account,
      plan_id:,
      success_url: confirm_settings_billing_index_url,
      cancel_url: settings_billing_index_url
    )

    redirect_to checkout_url, allow_other_host: true
  end

  # Mock-only. A real provider must not activate a plan from a browser
  # redirect, which the user controls — it activates from a signature-verified
  # webhook instead. ensure_mock_provider! closes this route the moment a real
  # provider is wired in, rather than leaving a weaker path available.
  def confirm
    payload = Billing.provider.verify_checkout_token(params[:token], account: current_account)

    if payload.blank?
      return redirect_to settings_billing_index_path, alert: I18n.t('billing_checkout_failed')
    end

    Billing::Subscription.assign!(
      account: current_account,
      plan_id: payload['plan_id'],
      external_id: Billing.provider.subscription_id_for(payload),
      period_end: 1.month.from_now
    )

    redirect_to settings_billing_index_path, notice: I18n.t('billing_plan_updated')
  end

  def cancel
    Billing::Subscription.assign!(account: current_account, plan_id: Billing::DEFAULT_PLAN_ID)

    redirect_to settings_billing_index_path, notice: I18n.t('billing_plan_updated')
  end

  private

  def load_subscription
    @subscription = Billing::Subscription.for(current_account)
  end

  def ensure_billing_enabled!
    redirect_to root_path unless Billing.enabled?
  end

  def ensure_mock_provider!
    redirect_to settings_billing_index_path, alert: I18n.t('billing_checkout_failed') unless Billing.mock_provider?
  end
end
