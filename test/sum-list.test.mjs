import { test } from "node:test";
import assert from "node:assert/strict";
import { sumList } from "../lib/sum-list.mjs";

test("sums three numbers", () => {
  assert.equal(sumList([1, 2, 3]), 6);
});

test("sums negative numbers", () => {
  assert.equal(sumList([-4, 10, -1]), 5);
});

test("returns 0 for an empty array", () => {
  assert.equal(sumList([]), 0);
});

test("rejects a non-array", () => {
  assert.throws(() => sumList("1,2,3"), TypeError);
});

test("rejects an array holding a non-number", () => {
  assert.throws(() => sumList([1, "2", 3]), TypeError);
});
