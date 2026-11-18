import { test } from "node:test";
import assert from "node:assert/strict";
import { clamp } from "../lib/clamp.mjs";

test("returns a value inside the range unchanged", () => {
  assert.equal(clamp(5, 0, 10), 5);
});

test("raises a value below the range to min", () => {
  assert.equal(clamp(-3, 0, 10), 0);
});

test("lowers a value above the range to max", () => {
  assert.equal(clamp(42, 0, 10), 10);
});

test("rejects a non-number", () => {
  assert.throws(() => clamp("5", 0, 10), TypeError);
  assert.throws(() => clamp(5, null, 10), TypeError);
  assert.throws(() => clamp(5, 0, undefined), TypeError);
});

test("rejects min greater than max", () => {
  assert.throws(() => clamp(5, 10, 0), RangeError);
});
