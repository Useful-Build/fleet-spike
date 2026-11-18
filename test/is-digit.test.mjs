import { test } from "node:test";
import assert from "node:assert/strict";
import { isDigit } from "../lib/is-digit.mjs";

test("returns true for a digit", () => {
  assert.equal(isDigit("7"), true);
});

test("returns false for a letter", () => {
  assert.equal(isDigit("a"), false);
});

test("returns false for a space", () => {
  assert.equal(isDigit(" "), false);
});

test("throws a TypeError for a string longer than one character", () => {
  assert.throws(() => isDigit("12"), TypeError);
});

test("throws a TypeError for a non-string", () => {
  assert.throws(() => isDigit(7), TypeError);
});
