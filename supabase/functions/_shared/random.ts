/** Cryptographically secure uniform float in [0, 1) with 53 bits of precision. */
export function secureRandom(): number {
  const words = new Uint32Array(2);
  crypto.getRandomValues(words);
  const high = words[0] >>> 5; // 27 bits
  const low = words[1] >>> 6; // 26 bits
  return (high * 67108864 + low) / 9007199254740992; // (high * 2^26 + low) / 2^53
}
