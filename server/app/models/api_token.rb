require "digest"
require "securerandom"

class ApiToken < ApplicationRecord
  belongs_to :user

  scope :active, -> { where(revoked_at: nil) }

  attr_reader :raw_token

  def self.issue!(user:, device_label: nil)
    raw = SecureRandom.urlsafe_base64(32)
    record = create!(
      user: user,
      token_digest: digest(raw),
      device_label: device_label
    )
    record.instance_variable_set(:@raw_token, raw)
    record
  end

  def self.authenticate(raw_token)
    return nil if raw_token.blank?

    token = active.find_by(token_digest: digest(raw_token))
    return nil unless token

    token.touch(:last_used_at)
    token
  end

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token.to_s)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def revoked?
    revoked_at.present?
  end
end
