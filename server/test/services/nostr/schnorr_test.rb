require "test_helper"

class Nostr::SchnorrTest < ActiveSupport::TestCase
  setup do
    event = signed_nostr_event
    @pubkey = [ event["pubkey"] ].pack("H*")
    @msg = [ event["id"] ].pack("H*")
    @sig = [ event["sig"] ].pack("H*")
  end

  test "accepts a signature produced by nostr-tools" do
    assert Nostr::Schnorr.valid?(@pubkey, @msg, @sig)
  end

  test "rejects a tampered signature" do
    tampered = @sig.dup
    tampered.setbyte(63, tampered.getbyte(63) ^ 0x01)
    assert_not Nostr::Schnorr.valid?(@pubkey, @msg, tampered)
  end

  test "rejects a signature over a different message" do
    assert_not Nostr::Schnorr.valid?(@pubkey, "\x00".b * 32, @sig)
  end

  test "rejects malformed input lengths" do
    assert_not Nostr::Schnorr.valid?(@pubkey.byteslice(0, 31), @msg, @sig)
    assert_not Nostr::Schnorr.valid?(@pubkey, @msg, @sig.byteslice(0, 63))
  end
end
