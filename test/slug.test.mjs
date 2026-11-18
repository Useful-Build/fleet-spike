import { test } from "node:test";
import assert from "node:assert/strict";
import { slugify } from "../lib/slug.mjs";

test("joins words with single dashes", () => {
  assert.equal(slugify("  Hello,   World! "), "hello-world");
});

test("drops accents", () => {
  assert.equal(slugify("Crème Brûlée"), "creme-brulee");
});

test("rejects non-strings", () => {
  assert.throws(() => slugify(42), TypeError);
});
