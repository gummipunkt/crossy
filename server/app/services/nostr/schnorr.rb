require "digest"

module Nostr
  # BIP-340 Schnorr signature verification over secp256k1, used to check
  # Nostr events that were signed in the browser. Verification only: no secret
  # keys ever reach the server, so plain integer arithmetic is sufficient.
  module Schnorr
    P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
    N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
    G = [
      0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798,
      0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8
    ].freeze

    module_function

    # pubkey: 32-byte x-only key, sig: 64 bytes, msg: message bytes (all binary strings).
    def valid?(pubkey, msg, sig)
      return false unless pubkey.bytesize == 32 && sig.bytesize == 64

      point = lift_x(to_int(pubkey))
      r = to_int(sig.byteslice(0, 32))
      s = to_int(sig.byteslice(32, 32))
      return false if point.nil? || r >= P || s >= N

      e = to_int(tagged_hash("BIP0340/challenge", sig.byteslice(0, 32) + pubkey + msg)) % N
      result = add(mul(G, s), mul(point, N - e))
      !result.nil? && result[1].even? && result[0] == r
    end

    def lift_x(x)
      return nil if x >= P

      c = (x.pow(3, P) + 7) % P
      y = c.pow((P + 1) / 4, P)
      return nil unless y.pow(2, P) == c

      [ x, y.even? ? y : P - y ]
    end

    # Affine point addition; nil is the point at infinity.
    def add(p1, p2)
      return p2 if p1.nil?
      return p1 if p2.nil?
      return nil if p1[0] == p2[0] && p1[1] != p2[1]

      lam =
        if p1 == p2
          3 * p1[0] * p1[0] * (2 * p1[1]).pow(P - 2, P) % P
        else
          (p2[1] - p1[1]) * (p2[0] - p1[0]).pow(P - 2, P) % P
        end
      x3 = (lam * lam - p1[0] - p2[0]) % P
      [ x3, (lam * (p1[0] - x3) - p1[1]) % P ]
    end

    def mul(point, scalar)
      result = nil
      addend = point
      while scalar.positive?
        result = add(result, addend) if scalar.odd?
        addend = add(addend, addend)
        scalar >>= 1
      end
      result
    end

    def tagged_hash(tag, msg)
      tag_hash = Digest::SHA256.digest(tag)
      Digest::SHA256.digest(tag_hash + tag_hash + msg)
    end

    def to_int(bytes)
      bytes.unpack1("H*").to_i(16)
    end
  end
end
