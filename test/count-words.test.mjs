import { test } from "node:test";
import assert from "node:assert/strict";
import { countWords } from "../lib/count-words.mjs";

test("counts three words", () => {
  assert.equal(countWords("one two three"), 3);
});

test("ignores extra spaces between and around words", () => {
  assert.equal(countWords("  one   two \t three\n "), 3);
});

test("an empty string has no words", () => {
  assert.equal(countWords(""), 0);
  assert.equal(countWords("   "), 0);
});

test("rejects a non-string", () => {
  assert.throws(() => countWords(42), TypeError);
  assert.throws(() => countWords(null), TypeError);
  assert.throws(() => countWords(undefined), TypeError);
});
