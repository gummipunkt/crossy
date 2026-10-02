module Posting
  # Rich-text facets for Bluesky posts. Without them links, mentions and
  # hashtags show up as plain text. Facet offsets are UTF-8 byte positions.
  module BlueskyFacets
    URL = %r{(?:^|[\s(])(https?://[^\s<>"]+)}
    MENTION = /(?:^|[\s(])@((?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?)/i
    HASHTAG = /(?:^|\s)#([^\s#]*[^\d\s\p{P}][^\s#]*)/
    TRAILING_PUNCTUATION = /[.,;:!?)\]}'"]+\z/
    MAX_TAG_LENGTH = 64

    module_function

    # resolve_handle: callable returning the DID for a handle, or nil (the
    # mention then stays plain text).
    def build(text, resolve_handle:)
      facets = []

      each_match(text, URL) do |url, start|
        url = url.sub(TRAILING_PUNCTUATION, "")
        facets << facet(text, start, url, "link", "uri" => url)
      end

      each_match(text, MENTION) do |handle, start|
        did = resolve_handle.call(handle)
        facets << facet(text, start - 1, "@#{handle}", "mention", "did" => did) if did.present?
      end

      each_match(text, HASHTAG) do |tag, start|
        tag = tag.sub(TRAILING_PUNCTUATION, "")
        next if tag.empty? || tag.length > MAX_TAG_LENGTH

        facets << facet(text, start - 1, "##{tag}", "tag", "tag" => tag)
      end

      facets.sort_by { |f| f.dig("index", "byteStart") }
    end

    def each_match(text, regex)
      text.scan(regex) do
        match = Regexp.last_match
        yield match[1], match.begin(1)
      end
    end

    def facet(text, char_start, value, kind, attributes)
      byte_start = text[0, char_start].bytesize
      {
        "index" => { "byteStart" => byte_start, "byteEnd" => byte_start + value.bytesize },
        "features" => [ { "$type" => "app.bsky.richtext.facet##{kind}" }.merge(attributes) ]
      }
    end
  end
end
