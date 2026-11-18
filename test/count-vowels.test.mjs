import { test } from "node:test";
import assert from "node:assert/strict";
import { countVowels } from "../lib/count-vowels.mjs";

test("counts the vowels in a word", () => {
  assert.equal(countVowels("education"), 5);
});

test("returns 0 for a word without vowels", () => {
  assert.equal(countVowels("rhythm"), 0);
});

test("counts upper and lower case vowels", () => {
  assert.equal(countVowels("AbEcIdOfU"), 5);
});

test("returns 0 for an empty string", () => {
  assert.equal(countVowels(""), 0);
});

test("throws a TypeError for a non-string", () => {
  assert.throws(() => countVowels(42), TypeError);
  assert.throws(() => countVowels(null), TypeError);
});
