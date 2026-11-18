import { test } from "node:test";
import assert from "node:assert/strict";
import { maxOf } from "../lib/max-of.mjs";

test("finds the largest of three numbers", () => {
  assert.equal(maxOf([3, 9, 4]), 9);
});

test("finds the largest of negative numbers", () => {
  assert.equal(maxOf([-7, -2, -15]), -2);
});

test("returns the only number", () => {
  assert.equal(maxOf([42]), 42);
});

test("throws a RangeError on an empty array", () => {
  assert.throws(() => maxOf([]), RangeError);
});

test("throws a TypeError on a non-array", () => {
  assert.throws(() => maxOf("1,2,3"), TypeError);
  assert.throws(() => maxOf(undefined), TypeError);
});

test("throws a TypeError on an array holding a non-number", () => {
  assert.throws(() => maxOf([1, "2", 3]), TypeError);
});
