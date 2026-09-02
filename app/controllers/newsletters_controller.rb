# frozen_string_literal: true

class NewslettersController < ApplicationController
  skip_authorization_check

  def show; end

  def update
    # No-op unless an endpoint is configured. This used to post the address to
    # the upstream project's servers, which is not where this product's users
    # expect their email to go. The redirect is left to the ensure block below,
    # which already runs on every path.
    if Docuseal::NEWSLETTER_URL.present?
      Faraday.post(Docuseal::NEWSLETTER_URL, newsletter_params.to_json, 'Content-Type' => 'application/json')
    end
  rescue StandardError => e
    Rails.logger.error(e)
  ensure
    redirect_to root_path
  end

  private

  def newsletter_params
    params.require(:user).permit(:email)
  end
end
