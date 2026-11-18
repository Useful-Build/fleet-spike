import { test } from "node:test";
import assert from "node:assert/strict";
import { isOdd } from "../lib/is-odd.mjs";

test("returns true for an odd number", () => {
  assert.equal(isOdd(7), true);
});

test("returns false for an even number", () => {
  assert.equal(isOdd(8), false);
});

test("returns false for zero", () => {
  assert.equal(isOdd(0), false);
});

test("returns true for a negative odd number", () => {
  assert.equal(isOdd(-3), true);
});

test("throws a TypeError for a non-integer", () => {
  assert.throws(() => isOdd(1.5), TypeError);
});
