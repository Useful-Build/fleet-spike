import { test } from "node:test";
import assert from "node:assert/strict";
import { capitalize } from "../lib/capitalize.mjs";

test("capitalizes a lower case word", () => {
  assert.equal(capitalize("hello"), "Hello");
});

test("leaves the rest of the text unchanged", () => {
  assert.equal(capitalize("hELLO wORLD"), "HELLO wORLD");
});

test("returns an already capitalized word unchanged", () => {
  assert.equal(capitalize("Hello"), "Hello");
});

test("capitalizes a single character", () => {
  assert.equal(capitalize("a"), "A");
});

test("capitalizes a first character outside the BMP without splitting it", () => {
  assert.equal(capitalize("\u{10428}bc"), "\u{10400}bc");
});

test("returns an empty string for an empty string", () => {
  assert.equal(capitalize(""), "");
});

test("rejects a non-string", () => {
  assert.throws(() => capitalize(42), TypeError);
  assert.throws(() => capitalize(null), TypeError);
  assert.throws(() => capitalize(undefined), TypeError);
  assert.throws(() => capitalize(["hello"]), TypeError);
});
