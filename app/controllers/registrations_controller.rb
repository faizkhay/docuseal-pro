# frozen_string_literal: true

# Self-serve sign-up: provisions a new tenant (Account) together with its first
# admin User. SetupController covers the very first account on an instance and
# also stores the instance-wide app URL; this covers every account after it.
class RegistrationsController < ApplicationController
  # Counts attempts, not just successes, so a validation error costs a try.
  # Set high enough that a shared office IP is not locked out by typos, low
  # enough to stop scripted sign-ups. RateLimit uses a per-process memory
  # store, so this is a speed bump rather than a hard guarantee across workers.
  SIGNUP_LIMIT = 10
  SIGNUP_PERIOD = 1.hour

  skip_before_action :maybe_redirect_to_setup
  skip_before_action :authenticate_user!
  skip_authorization_check

  before_action :redirect_to_root_if_signed, if: :signed_in?
  before_action :ensure_signup_enabled!
  before_action :ensure_instance_configured!

  # ApplicationController's handler redirects to request.referer, which raises
  # when the header is absent. Redirect somewhere known instead, and use a plain
  # 302 so Turbo follows it and the alert is actually shown on the form.
  rescue_from RateLimit::LimitApproached do
    redirect_to new_registration_path, alert: I18n.t('too_many_requests')
  end

  def new
    @account = Account.new(account_params)
    @user = @account.users.new(user_params)
  end

  def create
    throttle!

    @account = Account.new(account_params)
    @account.timezone = Accounts.normalize_timezone(@account.timezone)
    @user = @account.users.new(user_params)

    # Account carries no model-level validations, so the company name is
    # enforced here rather than trusting the browser's required attribute.
    if @account.name.blank?
      @account.errors.add(:name, :blank)

      return render :new, status: :unprocessable_content
    end

    # Saving the user autosaves the account it belongs to.
    if @user.save
      provision_account!

      sign_in(@user)

      redirect_to root_path, notice: I18n.t('your_account_has_been_created')
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  # Each tenant signs with its own certificate, so it has to be generated per
  # account. The app URL is deliberately not written here: it is instance-wide
  # and read from ENV['APP_URL'] or the first account's config.
  def provision_account!
    @account.encrypted_configs.create!(
      key: EncryptedConfig::ESIGN_CERTS_KEY,
      value: GenerateCertificate.call.transform_values(&:to_pem)
    )

    @account.account_configs.create!(key: :fulltext_search, value: true) if SearchEntry.table_exists?
  end

  def throttle!
    RateLimit.call("signup-#{request.remote_ip}", limit: SIGNUP_LIMIT, ttl: SIGNUP_PERIOD, enabled: true)
  end

  def user_params
    return {} unless params[:user]

    params.require(:user).permit(:first_name, :last_name, :email, :password)
  end

  def account_params
    return {} unless params[:account]

    params.require(:account).permit(:name, :timezone)
  end

  def redirect_to_root_if_signed
    redirect_to root_path, notice: I18n.t('you_are_already_signed_in')
  end

  def ensure_signup_enabled!
    redirect_to new_user_session_path unless Docuseal.signup_enabled?
  end

  # Until the first admin exists the instance has no app URL and no e-signing
  # certificates, so sign-ups have nothing to attach to.
  def ensure_instance_configured!
    redirect_to setup_index_path unless User.exists?
  end
end
