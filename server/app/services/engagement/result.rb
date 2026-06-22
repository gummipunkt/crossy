module Engagement
  # Per-network engagement payload returned by fetchers.
  # `replies` is an array of hashes with: remote_id, author_handle, author_name,
  # author_avatar_url, content, posted_at, permalink.
  Result = Struct.new(
    :like_count, :reply_count, :repost_count, :replies,
    keyword_init: true
  ) do
    def self.empty
      new(like_count: 0, reply_count: 0, repost_count: 0, replies: [])
    end
  end
end
