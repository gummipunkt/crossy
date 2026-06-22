class ThreadsFollow < ApplicationRecord
  belongs_to :provider_account

  validates :username, presence: true,
                       length: { maximum: 64 },
                       uniqueness: { scope: :provider_account_id, case_sensitive: false }
  validate  :provider_must_be_threads

  scope :active, -> { where(active: true) }

  before_validation :normalize_username

  def display_username
    "@#{username}"
  end

  private

  def normalize_username
    return if username.blank?
    cleaned = username.to_s.strip
    cleaned = cleaned.delete_prefix("@")
    self.username = cleaned.downcase
  end

  def provider_must_be_threads
    return if provider_account.blank?
    return if provider_account.provider == "threads"
    errors.add(:provider_account, "must be a Threads account")
  end
end
