import { test } from "node:test";
import assert from "node:assert/strict";
import { startsWithUpper } from "../lib/starts-with-upper.mjs";

test("returns true for an upper case start", () => {
  assert.equal(startsWithUpper("Hello world"), true);
  assert.equal(startsWithUpper("A"), true);
  assert.equal(startsWithUpper("Élan"), true);
});

test("returns false for a lower case start", () => {
  assert.equal(startsWithUpper("hello World"), false);
  assert.equal(startsWithUpper("élan"), false);
});

test("returns false for a digit start", () => {
  assert.equal(startsWithUpper("1st Place"), false);
});

test("returns false for a non-letter start", () => {
  assert.equal(startsWithUpper(" Hello"), false);
  assert.equal(startsWithUpper("!Hello"), false);
});

test("returns false for an empty string", () => {
  assert.equal(startsWithUpper(""), false);
});

test("rejects a non-string", () => {
  assert.throws(() => startsWithUpper(42), TypeError);
  assert.throws(() => startsWithUpper(null), TypeError);
  assert.throws(() => startsWithUpper(undefined), TypeError);
  assert.throws(() => startsWithUpper(["A"]), TypeError);
});
