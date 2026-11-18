import { test } from "node:test";
import assert from "node:assert/strict";
import { stripSpaces } from "../lib/strip-spaces.mjs";

test("removes spaces between words", () => {
  assert.equal(stripSpaces(" hello  big world "), "hellobigworld");
});

test("removes tabs and newlines", () => {
  assert.equal(stripSpaces("a\tb\nc\r\n\td"), "abcd");
});

test("returns text with no whitespace unchanged", () => {
  assert.equal(stripSpaces("hello-world"), "hello-world");
});

test("returns an empty string for an empty string", () => {
  assert.equal(stripSpaces(""), "");
});

test("rejects a non-string", () => {
  assert.throws(() => stripSpaces(42), TypeError);
  assert.throws(() => stripSpaces(null), TypeError);
});
