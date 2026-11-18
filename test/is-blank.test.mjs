import { test } from "node:test";
import assert from "node:assert/strict";
import { isBlank } from "../lib/is-blank.mjs";

test("an empty string is blank", () => {
  assert.equal(isBlank(""), true);
});

test("spaces and tabs are blank", () => {
  assert.equal(isBlank("  \t \t"), true);
});

test("a word is not blank", () => {
  assert.equal(isBlank("hello"), false);
});

test("a word with spaces around it is not blank", () => {
  assert.equal(isBlank("  hello \t"), false);
});

test("rejects a non-string", () => {
  assert.throws(() => isBlank(42), TypeError);
  assert.throws(() => isBlank(null), TypeError);
  assert.throws(() => isBlank(undefined), TypeError);
});
