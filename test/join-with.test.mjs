import { test } from "node:test";
import assert from "node:assert/strict";
import { joinWith } from "../lib/join-with.mjs";

test("joins three strings with the separator", () => {
  assert.equal(joinWith(["a", "b", "c"], ", "), "a, b, c");
});

test("returns one string unchanged", () => {
  assert.equal(joinWith(["only"], "-"), "only");
});

test("returns an empty string for an empty array", () => {
  assert.equal(joinWith([], "-"), "");
});

test("throws a TypeError for a non-array", () => {
  assert.throws(() => joinWith("a,b", ","), TypeError);
});

test("throws a TypeError for an array holding a non-string", () => {
  assert.throws(() => joinWith(["a", 2, "c"], ","), TypeError);
});
