class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  has_many :provider_accounts, dependent: :destroy
  has_many :posts, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
end
