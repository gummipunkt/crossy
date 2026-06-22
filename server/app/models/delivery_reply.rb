class DeliveryReply < ApplicationRecord
  belongs_to :delivery

  validates :remote_id, presence: true, uniqueness: { scope: :delivery_id }
end
