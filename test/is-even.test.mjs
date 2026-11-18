import { test } from "node:test";
import assert from "node:assert/strict";
import { isEven } from "../lib/is-even.mjs";

test("isEven: an even number is even", () => {
  assert.equal(isEven(4), true);
});

test("isEven: an odd number is not even", () => {
  assert.equal(isEven(7), false);
});

test("isEven: zero is even", () => {
  assert.equal(isEven(0), true);
});

test("isEven: a negative even number is even", () => {
  assert.equal(isEven(-6), true);
});

test("isEven: a non-integer throws a TypeError", () => {
  assert.throws(() => isEven(2.5), TypeError);
  assert.throws(() => isEven("4"), TypeError);
});
