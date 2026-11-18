import { test } from "node:test";
import assert from "node:assert/strict";
import { chunkList } from "../lib/chunk-list.mjs";

test("splits an array evenly", () => {
  assert.deepEqual(chunkList([1, 2, 3, 4, 5, 6], 2), [[1, 2], [3, 4], [5, 6]]);
});

test("leaves the last chunk shorter on an uneven split", () => {
  assert.deepEqual(chunkList([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]]);
});

test("returns one chunk when size is larger than the array", () => {
  assert.deepEqual(chunkList([1, 2, 3], 10), [[1, 2, 3]]);
});

test("returns no chunks for an empty array", () => {
  assert.deepEqual(chunkList([], 3), []);
});

test("throws a RangeError for a size below 1", () => {
  assert.throws(() => chunkList([1, 2], 0), RangeError);
  assert.throws(() => chunkList([1, 2], -1), RangeError);
});

test("throws a RangeError for a size that is not an integer", () => {
  assert.throws(() => chunkList([1, 2], 1.5), RangeError);
  assert.throws(() => chunkList([1, 2], "2"), RangeError);
});

test("throws a TypeError for a non-array", () => {
  assert.throws(() => chunkList("abc", 1), TypeError);
});
