module Engagement
  # Per-network engagement payload returned by fetchers.
  #
  # `replies`: array of hashes with: remote_id, author_handle, author_name,
  #   author_avatar_url, content, posted_at, permalink.
  # `likers` / `reposters`: array of hashes with: remote_id (author identifier),
  #   author_handle, author_name, author_avatar_url, author_url, reacted_at.
  Result = Struct.new(
    :like_count, :reply_count, :repost_count,
    :replies, :likers, :reposters,
    keyword_init: true
  ) do
    def self.empty
      new(
        like_count: 0, reply_count: 0, repost_count: 0,
        replies: [], likers: [], reposters: []
      )
    end
  end
end
