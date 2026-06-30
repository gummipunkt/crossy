class DeliveryReaction < ApplicationRecord
  belongs_to :delivery

  KINDS = %w[like repost].freeze

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :remote_id, presence: true, uniqueness: { scope: [ :delivery_id, :kind ] }

  scope :likes,   -> { where(kind: "like") }
  scope :reposts, -> { where(kind: "repost") }

  def like?;   kind == "like";   end
  def repost?; kind == "repost"; end
end
