import { test } from "node:test";
import assert from "node:assert/strict";
import { average } from "../lib/average.mjs";

test("averages three numbers", () => {
  assert.equal(average([1, 2, 6]), 3);
});

test("averages negative numbers", () => {
  assert.equal(average([-4, -2, 0]), -2);
});

test("averages one number", () => {
  assert.equal(average([7]), 7);
});

test("throws a RangeError on an empty array", () => {
  assert.throws(() => average([]), RangeError);
});

test("throws a TypeError on a non-array", () => {
  assert.throws(() => average("1,2,3"), TypeError);
});
