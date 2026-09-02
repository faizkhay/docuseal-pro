# frozen_string_literal: true

module Docuseal
  URL_CACHE = ActiveSupport::Cache::MemoryStore.new

  # Upstream project. The AGPL additional terms (LICENSE_ADDITIONAL_TERMS,
  # invoking section 7(b)) require this attribution to stay visible in
  # interactive user interfaces, so it is held separately from the product
  # brand rather than renamed along with it.
  UPSTREAM_NAME = 'DocuSeal'
  UPSTREAM_URL = 'https://www.docuseal.com'

  DEFAULT_APP_URL = ENV.fetch('APP_URL', 'http://localhost:3000')

  PRODUCT_NAME = ENV.fetch('PRODUCT_NAME', 'SignDocuMate')
  PRODUCT_URL = ENV.fetch('PRODUCT_URL', DEFAULT_APP_URL)
  PRODUCT_EMAIL_URL = ENV.fetch('PRODUCT_EMAIL_URL', PRODUCT_URL)

  # Community links and outbound endpoints, unset unless configured. They
  # previously pointed at the upstream project, which under a different brand
  # sends this product's users to someone else's community and their email
  # addresses to someone else's servers.
  GITHUB_URL = ENV.fetch('GITHUB_URL', nil)
  DISCORD_URL = ENV.fetch('DISCORD_URL', nil)
  TWITTER_URL = ENV.fetch('TWITTER_URL', nil)
  TWITTER_HANDLE = ENV.fetch('TWITTER_HANDLE', nil)
  NEWSLETTER_URL = ENV.fetch('NEWSLETTER_URL', nil)
  ENQUIRIES_URL = ENV.fetch('ENQUIRIES_URL', nil)
  CHATGPT_URL = ENV.fetch('CHATGPT_URL', nil)
  SUPPORT_EMAIL = ENV.fetch('SUPPORT_EMAIL', nil)
  HOST = ENV.fetch('HOST', 'localhost')
  AATL_CERT_NAME = 'docuseal_aatl'
  CONSOLE_URL = if Rails.env.development?
                  'http://console.localhost.io:3001'
                elsif ENV['MULTITENANT'] == 'true'
                  "https://console.#{HOST}"
                else
                  'https://console.docuseal.com'
                end
  CLOUD_URL = if Rails.env.development?
                'http://localhost:3000'
              else
                'https://docuseal.com'
              end
  CDN_URL = if Rails.env.development?
              'http://localhost:3000'
            elsif ENV['MULTITENANT'] == 'true'
              "https://cdn.#{HOST}"
            else
              'https://cdn.docuseal.com'
            end

  CERTS = JSON.parse(ENV.fetch('CERTS', '{}'))
  TIMESERVER_URL = ENV.fetch('TIMESERVER_URL', nil)
  VERSION_FILE_PATH = Rails.root.join('.version')
  VERSION_FILE2_PATH = Rails.public_path.join('version')

  DEFAULT_URL_OPTIONS = {
    host: HOST,
    protocol: ENV['FORCE_SSL'].present? ? 'https' : 'http'
  }.freeze

  module_function

  def version
    @version ||=
      if VERSION_FILE_PATH.exist?
        VERSION_FILE_PATH.read.strip
      elsif VERSION_FILE2_PATH.exist?
        VERSION_FILE2_PATH.each_line.first.to_s.strip
      end
  end

  def multitenant?
    ENV['MULTITENANT'] == 'true'
  end

  def advanced_formats?
    multitenant?
  end

  def demo?
    ENV['DEMO'] == 'true'
  end

  # Public self-serve registration. Off unless explicitly enabled, so that a
  # private instance is never left accepting sign-ups by accident.
  def signup_enabled?
    ENV['SIGNUP_ENABLED'] == 'true'
  end

  def active_storage_public?
    ENV['ACTIVE_STORAGE_PUBLIC'] == 'true'
  end

  def default_pkcs
    return if Docuseal::CERTS['enabled'] == false

    @default_pkcs ||= GenerateCertificate.load_pkcs(Docuseal::CERTS)
  end

  def fulltext_search?
    return @fulltext_search unless @fulltext_search.nil?

    @fulltext_search =
      if SearchEntry.table_exists?
        Docuseal.multitenant? || AccountConfig.exists?(key: :fulltext_search, value: true)
      else
        false
      end
  end

  def enable_pwa?
    true
  end

  def pdf_format
    @pdf_format ||= ENV['PDF_FORMAT'].to_s.downcase
  end

  def trusted_certs
    @trusted_certs ||=
      ENV['TRUSTED_CERTS'].to_s.gsub('\\n', "\n").split("\n\n").map do |base64|
        OpenSSL::X509::Certificate.new(base64)
      end
  end

  def default_url_options
    return DEFAULT_URL_OPTIONS if multitenant?

    @default_url_options ||= begin
      value = EncryptedConfig.find_by(key: EncryptedConfig::APP_URL_KEY)&.value if ENV['APP_URL'].blank?
      value ||= DEFAULT_APP_URL
      url = Addressable::URI.parse(value)
      { host: url.host, port: url.port, protocol: url.scheme }
    end
  end

  def product_name
    PRODUCT_NAME
  end

  def refresh_default_url_options!
    @default_url_options = nil
  end
end
