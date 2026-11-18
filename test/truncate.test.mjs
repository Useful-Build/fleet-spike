import { test } from "node:test";
import assert from "node:assert/strict";
import { truncate } from "../lib/truncate.mjs";

test("returns text shorter than max unchanged", () => {
  assert.equal(truncate("hello", 10), "hello");
});

test("returns text of exactly max characters unchanged", () => {
  assert.equal(truncate("hello", 5), "hello");
});

test("cuts text longer than max to max characters ending in an ellipsis", () => {
  const result = truncate("hello world", 8);
  assert.equal(result, "hello w…");
  assert.equal(result.length, 8);
});

test("max of 1 leaves only the ellipsis", () => {
  assert.equal(truncate("hello", 1), "…");
});

test("rejects max below 1", () => {
  assert.throws(() => truncate("hello", 0), RangeError);
  assert.throws(() => truncate("hello", -3), RangeError);
});

test("rejects max that isn't a whole number", () => {
  assert.throws(() => truncate("hello", 2.5), RangeError);
  assert.throws(() => truncate("hello", NaN), RangeError);
  assert.throws(() => truncate("hello", "5"), RangeError);
});
