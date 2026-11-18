import { test } from "node:test";
import assert from "node:assert/strict";
import { uniqueItems } from "../lib/unique-items.mjs";

test("drops repeated numbers and keeps first-seen order", () => {
  assert.deepEqual(uniqueItems([3, 1, 3, 2, 1]), [3, 1, 2]);
});

test("drops repeated strings and keeps first-seen order", () => {
  assert.deepEqual(uniqueItems(["b", "a", "b", "c", "a"]), ["b", "a", "c"]);
});

test("returns a new array equal to one with no repeats", () => {
  const items = [1, 2, 3];
  const result = uniqueItems(items);
  assert.deepEqual(result, [1, 2, 3]);
  assert.notEqual(result, items);
});

test("returns an empty array for an empty array", () => {
  assert.deepEqual(uniqueItems([]), []);
});

test("throws a TypeError for a non-array", () => {
  assert.throws(() => uniqueItems("abc"), TypeError);
  assert.throws(() => uniqueItems(null), TypeError);
});
