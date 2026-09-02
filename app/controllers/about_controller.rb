# frozen_string_literal: true

# Carries the "Appropriate Legal Notices" that AGPL-3.0 section 0 describes:
# copyright, warranty disclaimer, licence, and how to obtain the source. Public
# because section 13 obliges the offer to reach anyone using the service over a
# network, including recipients who only ever open a signing link.
class AboutController < ApplicationController
  skip_before_action :maybe_redirect_to_setup
  skip_before_action :authenticate_user!
  skip_authorization_check

  layout 'plain'

  def show; end
end
