class ProviderAccount < ApplicationRecord
  PROVIDERS = %w[mastodon bluesky threads nostr].freeze
  PROVIDER_ALIASES = {
    "bsky" => "bluesky",
    "atproto" => "bluesky"
  }.freeze

  belongs_to :user, optional: true

  has_many :deliveries, dependent: :destroy
  has_many :posts, through: :deliveries

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :handle, presence: true

  # Instance is optional for providers die keine Instanz brauchen (z. B. Bluesky/Threads)

  # Encrypted fields via Lockbox (uses *_ciphertext columns)
  has_encrypted :access_token
  has_encrypted :refresh_token

  # Searchable blind index for Handle
  blind_index :handle

  before_validation :normalize_provider
  before_validation :normalize_instance

  private

  def normalize_provider
    return if provider.blank?
    normalized = provider.to_s.strip.downcase
    normalized = PROVIDER_ALIASES.fetch(normalized, normalized)
    self.provider = normalized
  end

  def normalize_instance
    return if instance.blank?
    url = instance.to_s.strip
    unless url.start_with?("http://", "https://")
      url = "https://#{url}"
    end
    # Remove trailing slashes for consistency
    self.instance = url.sub(%r{/+$}, "")
  end
end


