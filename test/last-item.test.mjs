import { test } from "node:test";
import assert from "node:assert/strict";
import { lastItem } from "../lib/last-item.mjs";

test("returns the last of three values", () => {
  assert.equal(lastItem([1, 2, 3]), 3);
});

test("returns the only value of a one-value array", () => {
  assert.equal(lastItem(["only"]), "only");
});

test("returns the last value of mixed types", () => {
  const last = { a: 1 };
  assert.equal(lastItem([1, "two", null, last]), last);
  assert.equal(lastItem(["x", 2, undefined]), undefined);
});

test("rejects an empty array", () => {
  assert.throws(() => lastItem([]), RangeError);
});

test("rejects a non-array", () => {
  assert.throws(() => lastItem("abc"), TypeError);
  assert.throws(() => lastItem(null), TypeError);
  assert.throws(() => lastItem(undefined), TypeError);
  assert.throws(() => lastItem({ length: 1, 0: "a" }), TypeError);
});
