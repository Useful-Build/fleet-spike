import { test } from "node:test";
import assert from "node:assert/strict";
import { absDiff } from "../lib/abs-diff.mjs";

test("absDiff: larger first number", () => {
  assert.equal(absDiff(10, 3), 7);
});

test("absDiff: larger second number", () => {
  assert.equal(absDiff(3, 10), 7);
});

test("absDiff: equal numbers", () => {
  assert.equal(absDiff(5, 5), 0);
});

test("absDiff: negative numbers", () => {
  assert.equal(absDiff(-4, -9), 5);
  assert.equal(absDiff(-4, 6), 10);
});

test("absDiff: rejects a non-number", () => {
  assert.throws(() => absDiff("3", 1), TypeError);
  assert.throws(() => absDiff(1, null), TypeError);
  assert.throws(() => absDiff(undefined, 1), TypeError);
});
