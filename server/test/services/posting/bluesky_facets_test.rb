require "test_helper"

class Posting::BlueskyFacetsTest < ActiveSupport::TestCase
  RESOLVER = ->(handle) { handle == "unknown.test" ? nil : "did:plc:#{handle}" }

  test "links, mentions and hashtags get UTF-8 byte offsets" do
    text = "Grüße @alice.bsky.social! Siehe https://example.com/a?b=1. #Ruby"
    facets = Posting::BlueskyFacets.build(text, resolve_handle: RESOLVER)

    assert_equal [ "@alice.bsky.social", "https://example.com/a?b=1", "#Ruby" ], facets.map { |f| slice(text, f) }
    assert_equal({ "$type" => "app.bsky.richtext.facet#mention", "did" => "did:plc:alice.bsky.social" }, facets[0]["features"].first)
    assert_equal "https://example.com/a?b=1", facets[1]["features"].first["uri"]
    assert_equal "Ruby", facets[2]["features"].first["tag"]
  end

  test "ignores e-mail addresses, numeric tags and unresolvable handles" do
    text = "mail me@example.com #2024 @unknown.test"
    assert_empty Posting::BlueskyFacets.build(text, resolve_handle: RESOLVER)
  end

  private

  def slice(text, facet)
    index = facet["index"]
    text.byteslice(index["byteStart"], index["byteEnd"] - index["byteStart"]).force_encoding(Encoding::UTF_8)
  end
end
