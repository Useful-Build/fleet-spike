import { test } from "node:test";
import assert from "node:assert/strict";
import { padLeft } from "../lib/pad-left.mjs";

test("pads shorter text on the left", () => {
  assert.equal(padLeft("7", 3, "0"), "007");
});

test("leaves text of exactly width unchanged", () => {
  assert.equal(padLeft("abc", 3, "*"), "abc");
});

test("leaves longer text unchanged", () => {
  assert.equal(padLeft("abcdef", 3, " "), "abcdef");
});

test("throws a TypeError for non-string text", () => {
  assert.throws(() => padLeft(42, 5, "0"), TypeError);
});

test("throws a TypeError for a fill that is not one character", () => {
  assert.throws(() => padLeft("a", 5, ""), TypeError);
  assert.throws(() => padLeft("a", 5, "ab"), TypeError);
  assert.throws(() => padLeft("a", 5, 0), TypeError);
});
