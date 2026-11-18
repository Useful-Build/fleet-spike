import { test } from "node:test";
import assert from "node:assert/strict";
import { countChar } from "../lib/count-char.mjs";

test("counts several matches", () => {
  assert.equal(countChar("banana", "a"), 3);
});

test("returns 0 when there is no match", () => {
  assert.equal(countChar("banana", "z"), 0);
});

test("returns 0 for an empty text", () => {
  assert.equal(countChar("", "a"), 0);
});

test("throws a TypeError for a non-string text", () => {
  assert.throws(() => countChar(42, "a"), TypeError);
});

test("throws a TypeError for a char longer than one character", () => {
  assert.throws(() => countChar("banana", "an"), TypeError);
});

test("throws a TypeError for an empty or non-string char", () => {
  assert.throws(() => countChar("banana", ""), TypeError);
  assert.throws(() => countChar("banana", 1), TypeError);
});

test("counts a character outside the BMP", () => {
  assert.equal(countChar("😀a😀", "😀"), 2);
});
