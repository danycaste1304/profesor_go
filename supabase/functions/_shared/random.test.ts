import { assert } from "@std/assert";
import { secureRandom } from "./random.ts";

Deno.test("secureRandom: values are in [0, 1) and not constant", () => {
  const samples = Array.from({ length: 5000 }, secureRandom);
  assert(samples.every((x) => x >= 0 && x < 1));
  assert(new Set(samples).size > 4900);
  const mean = samples.reduce((a, b) => a + b, 0) / samples.length;
  assert(mean > 0.4 && mean < 0.6, `mean ${mean} looks biased`);
});
