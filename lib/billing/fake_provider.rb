# frozen_string_literal: true

module Billing
  # Stand-in for a hosted checkout (Stripe Checkout and friends). Instead of
  # sending the user to an external page it hands back a URL straight back into
  # this app, carrying a signed, expiring token.
  #
  # The signature is not decoration. It enforces the same trust boundary a real
  # integration needs: the confirm endpoint must only believe a payment
  # happened if the message is provably ours. Replacing this with Stripe means
  # verifying a webhook signature in the same place, rather than adding one.
  #
  # A real provider needs to answer:
  #   #name                      => identifier stored on the subscription
  #   #create_checkout_session   => URL to send the user to
  # and to give the controller some way to authenticate the callback.
  class FakeProvider
    TOKEN_TTL = 15.minutes
    VERIFIER_PURPOSE = 'billing_checkout'

    def name
      'fake'
    end

    def create_checkout_session(account:, plan_id:, success_url:, cancel_url: nil)
      token = verifier.generate({ 'account_id' => account.id, 'plan_id' => plan_id.to_s },
                                purpose: VERIFIER_PURPOSE, expires_in: TOKEN_TTL)

      append_query(success_url, token:, cancel_url:)
    end

    # Returns the payload when the token is ours, unexpired, and belongs to this
    # account; nil otherwise. Callers must treat nil as "no payment happened".
    def verify_checkout_token(token, account:)
      payload = verifier.verified(token.to_s, purpose: VERIFIER_PURPOSE)

      return if payload.blank?
      return if payload['account_id'] != account.id
      return unless Billing.plan?(payload['plan_id'])

      payload
    end

    # A real provider returns its own subscription id; mirror that shape.
    def subscription_id_for(payload)
      "fake_sub_#{payload['account_id']}_#{payload['plan_id']}"
    end

    private

    def verifier
      Rails.application.message_verifier(:billing)
    end

    def append_query(url, token:, cancel_url: nil)
      uri = URI.parse(url)
      existing = URI.decode_www_form(uri.query.to_s)
      uri.query = URI.encode_www_form(existing + [['token', token]])

      # cancel_url is accepted for interface parity with real providers; the
      # fake flow has nothing to cancel because it never leaves the app.
      _ = cancel_url

      uri.to_s
    end
  end
end
