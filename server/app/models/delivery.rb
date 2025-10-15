class Delivery < ApplicationRecord
  belongs_to :post
  belongs_to :provider_account

  # Rails 8 Enum-Syntax (string-backed)
  enum :status, {
    queued: "queued",
    in_progress: "in_progress",
    awaiting_signature: "awaiting_signature",
    succeeded: "succeeded",
    failed: "failed"
  }, validate: true

  validates :status, presence: true
end


