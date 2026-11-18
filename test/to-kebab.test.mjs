import { test } from "node:test";
import assert from "node:assert/strict";
import { toKebab } from "../lib/to-kebab.mjs";

test("toKebab joins two words with a dash", () => {
  assert.equal(toKebab("hello world"), "hello-world");
});

test("toKebab collapses extra spaces", () => {
  assert.equal(toKebab("  hello \t  big   world  "), "hello-big-world");
});

test("toKebab lower-cases mixed case", () => {
  assert.equal(toKebab("Hello WoRLD"), "hello-world");
});

test("toKebab returns an empty string when there are no words", () => {
  assert.equal(toKebab(""), "");
  assert.equal(toKebab("   "), "");
});

test("toKebab rejects non-strings", () => {
  assert.throws(() => toKebab(42), TypeError);
  assert.throws(() => toKebab(null), TypeError);
});
