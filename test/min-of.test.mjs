import { test } from "node:test";
import assert from "node:assert/strict";
import { minOf } from "../lib/min-of.mjs";

test("returns the smallest of three numbers", () => {
  assert.equal(minOf([7, 2, 9]), 2);
});

test("handles negative numbers", () => {
  assert.equal(minOf([-1, -8, 3]), -8);
});

test("returns the only number in a one-number array", () => {
  assert.equal(minOf([5]), 5);
});

test("throws a RangeError on an empty array", () => {
  assert.throws(() => minOf([]), RangeError);
});

test("throws a TypeError on a non-array", () => {
  assert.throws(() => minOf("1,2,3"), TypeError);
  assert.throws(() => minOf(undefined), TypeError);
});

test("throws a TypeError on an array holding a non-number", () => {
  assert.throws(() => minOf([1, "2", 3]), TypeError);
  assert.throws(() => minOf([1, NaN]), TypeError);
});
