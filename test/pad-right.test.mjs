import { test } from "node:test";
import assert from "node:assert/strict";
import { padRight } from "../lib/pad-right.mjs";

test("pads shorter text on the right to width", () => {
  assert.equal(padRight("ab", 5, "."), "ab...");
});

test("returns text of exactly width unchanged", () => {
  assert.equal(padRight("abcde", 5, "."), "abcde");
});

test("returns longer text unchanged", () => {
  assert.equal(padRight("abcdefg", 5, "."), "abcdefg");
});

test("rejects a non-string text", () => {
  assert.throws(() => padRight(42, 5, "."), TypeError);
});

test("rejects a fill that is not one character", () => {
  assert.throws(() => padRight("ab", 5, ""), TypeError);
  assert.throws(() => padRight("ab", 5, "--"), TypeError);
  assert.throws(() => padRight("ab", 5, 1), TypeError);
});
