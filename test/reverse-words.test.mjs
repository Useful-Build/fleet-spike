import { test } from "node:test";
import assert from "node:assert/strict";
import { reverseWords } from "../lib/reverse-words.mjs";

test("reverses three words", () => {
  assert.equal(reverseWords("one two three"), "three two one");
});

test("collapses extra spaces to single spaces", () => {
  assert.equal(reverseWords("  one   two  three  "), "three two one");
});

test("treats tabs and newlines as spaces", () => {
  assert.equal(reverseWords("one\ttwo\nthree"), "three two one");
});

test("returns one word unchanged", () => {
  assert.equal(reverseWords("hello"), "hello");
});

test("returns an empty string for an empty or all-space string", () => {
  assert.equal(reverseWords(""), "");
  assert.equal(reverseWords("    "), "");
});

test("rejects a non-string", () => {
  assert.throws(() => reverseWords(42), TypeError);
  assert.throws(() => reverseWords(null), TypeError);
  assert.throws(() => reverseWords(undefined), TypeError);
  assert.throws(() => reverseWords(["a", "b"]), TypeError);
});
