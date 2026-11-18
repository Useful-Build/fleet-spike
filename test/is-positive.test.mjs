import { test } from "node:test";
import assert from "node:assert/strict";
import { isPositive } from "../lib/is-positive.mjs";

test("a positive number is positive", () => {
  assert.equal(isPositive(5), true);
});

test("a negative number is not positive", () => {
  assert.equal(isPositive(-5), false);
});

test("zero is not positive", () => {
  assert.equal(isPositive(0), false);
  assert.equal(isPositive(-0), false);
});

test("a fraction above or below zero", () => {
  assert.equal(isPositive(0.25), true);
  assert.equal(isPositive(-0.25), false);
});

test("rejects a non-number or NaN", () => {
  assert.throws(() => isPositive("5"), TypeError);
  assert.throws(() => isPositive(null), TypeError);
  assert.throws(() => isPositive(undefined), TypeError);
  assert.throws(() => isPositive(NaN), TypeError);
});
