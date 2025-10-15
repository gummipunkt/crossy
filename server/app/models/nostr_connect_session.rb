class NostrConnectSession < ApplicationRecord
  belongs_to :provider_account

  # relays: array of relay URLs
  serialize :relays, type: Array, coder: JSON

  enum :status, {
    pending: "pending",
    active: "active",
    revoked: "revoked",
    expired: "expired"
  }, validate: true

  validates :app_public_key, presence: true
  validates :expires_at, presence: true

  scope :active_for, ->(pa_id) { where(provider_account_id: pa_id, status: "active").where("expires_at > ?", Time.current).order(id: :desc) }
end


