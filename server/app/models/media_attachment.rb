class MediaAttachment < ApplicationRecord
  belongs_to :post
  has_one_attached :file

  validates :filename, presence: true
  validates :content_type, presence: true
end


