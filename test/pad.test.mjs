import { test } from "node:test";
import assert from "node:assert/strict";
import { padLeft } from "../lib/pad.mjs";

test("pads text shorter than width on the left with spaces", () => {
  assert.equal(padLeft("42", 5), "   42");
});

test("returns text already at or past width unchanged", () => {
  assert.equal(padLeft("hello", 5), "hello");
  assert.equal(padLeft("hello world", 5), "hello world");
});

test("pads with a custom fill character", () => {
  assert.equal(padLeft("7", 3, "0"), "007");
});

test("rejects non-string text", () => {
  assert.throws(() => padLeft(42, 5), TypeError);
  assert.throws(() => padLeft(null, 5), TypeError);
});
