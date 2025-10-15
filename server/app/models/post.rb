class Post < ApplicationRecord
  has_many :deliveries, dependent: :destroy
  has_many :provider_accounts, through: :deliveries
  has_many :media_attachments, dependent: :destroy

  validates :content_text, presence: true
end


