import { test } from "node:test";
import assert from "node:assert/strict";
import { doubleAll } from "../lib/double-all.mjs";

test("doubles three numbers", () => {
  assert.deepEqual(doubleAll([1, 2.5, 3]), [2, 5, 6]);
});

test("doubles negative numbers", () => {
  assert.deepEqual(doubleAll([-1, -4, 0]), [-2, -8, 0]);
});

test("returns a new empty array for an empty array", () => {
  const input = [];
  const result = doubleAll(input);
  assert.deepEqual(result, []);
  assert.notEqual(result, input);
});

test("rejects a non-array", () => {
  assert.throws(() => doubleAll("1,2,3"), TypeError);
});

test("rejects an array holding a non-number", () => {
  assert.throws(() => doubleAll([1, "2", 3]), TypeError);
});
