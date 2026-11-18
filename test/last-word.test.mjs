import { test } from "node:test";
import assert from "node:assert/strict";
import { lastWord } from "../lib/last-word.mjs";

test("returns the only word", () => {
  assert.equal(lastWord("hello"), "hello");
});

test("returns the last of three words", () => {
  assert.equal(lastWord("one two three"), "three");
});

test("ignores trailing spaces", () => {
  assert.equal(lastWord("one two   \t\n"), "two");
});

test("returns an empty string when there is no word", () => {
  assert.equal(lastWord(""), "");
  assert.equal(lastWord("   "), "");
});

test("rejects a non-string", () => {
  assert.throws(() => lastWord(42), TypeError);
  assert.throws(() => lastWord(null), TypeError);
  assert.throws(() => lastWord(undefined), TypeError);
});
