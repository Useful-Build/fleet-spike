import { test } from "node:test";
import assert from "node:assert/strict";
import { initials } from "../lib/initials.mjs";

test("initials of two words", () => {
  assert.equal(initials("ada lovelace"), "AL");
});

test("initials ignore extra whitespace between and around words", () => {
  assert.equal(initials("  grace \t\n  hopper  "), "GH");
});

test("initials of an empty string is empty", () => {
  assert.equal(initials(""), "");
  assert.equal(initials("   "), "");
});

test("initials rejects a non-string", () => {
  assert.throws(() => initials(42), TypeError);
  assert.throws(() => initials(null), TypeError);
  assert.throws(() => initials(undefined), TypeError);
});
