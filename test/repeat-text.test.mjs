import { test } from "node:test";
import assert from "node:assert/strict";
import { repeatText } from "../lib/repeat-text.mjs";

test("repeats text three times", () => {
  assert.equal(repeatText("ab", 3), "ababab");
});

test("returns the text once for a count of one", () => {
  assert.equal(repeatText("ab", 1), "ab");
});

test("returns an empty string for a count of zero", () => {
  assert.equal(repeatText("ab", 0), "");
});

test("rejects a negative or non-integer count", () => {
  assert.throws(() => repeatText("ab", -1), RangeError);
  assert.throws(() => repeatText("ab", 1.5), RangeError);
  assert.throws(() => repeatText("ab", "2"), RangeError);
});

test("rejects a non-string", () => {
  assert.throws(() => repeatText(42, 2), TypeError);
  assert.throws(() => repeatText(null, 2), TypeError);
  assert.throws(() => repeatText(["ab"], 2), TypeError);
});
