import { test } from "node:test";
import assert from "node:assert/strict";
import { headOf } from "../lib/head-of.mjs";

test("returns the first of three values", () => {
  assert.equal(headOf([1, 2, 3]), 1);
});

test("returns the only value of a one value array", () => {
  assert.equal(headOf(["only"]), "only");
});

test("returns the first value of mixed types", () => {
  const first = { a: 1 };
  assert.equal(headOf([first, "two", 3, null]), first);
});

test("throws a RangeError on an empty array", () => {
  assert.throws(() => headOf([]), RangeError);
});

test("throws a TypeError on a non-array", () => {
  assert.throws(() => headOf("abc"), TypeError);
  assert.throws(() => headOf(undefined), TypeError);
});
