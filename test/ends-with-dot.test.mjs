import { test } from "node:test";
import assert from "node:assert/strict";
import { endsWithDot } from "../lib/ends-with-dot.mjs";

test("returns true for a sentence ending with a dot", () => {
  assert.equal(endsWithDot("This is a sentence."), true);
});

test("returns false for a sentence without a dot at the end", () => {
  assert.equal(endsWithDot("This is a sentence"), false);
  assert.equal(endsWithDot("A dot. Then more"), false);
});

test("returns false for an empty string", () => {
  assert.equal(endsWithDot(""), false);
});

test("rejects a non-string", () => {
  assert.throws(() => endsWithDot(42), TypeError);
  assert.throws(() => endsWithDot(null), TypeError);
  assert.throws(() => endsWithDot(undefined), TypeError);
  assert.throws(() => endsWithDot(["a."]), TypeError);
});
