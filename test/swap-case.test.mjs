import { test } from "node:test";
import assert from "node:assert/strict";
import { swapCase } from "../lib/swap-case.mjs";

test("swapCase makes lower case letters upper case", () => {
  assert.equal(swapCase("hello world"), "HELLO WORLD");
});

test("swapCase makes upper case letters lower case", () => {
  assert.equal(swapCase("HELLO WORLD"), "hello world");
});

test("swapCase swaps mixed case and leaves digits alone", () => {
  assert.equal(swapCase("Abc123dEF-9x"), "aBC123Def-9X");
});

test("swapCase returns an empty string for an empty string", () => {
  assert.equal(swapCase(""), "");
});

test("swapCase throws a TypeError for a non-string", () => {
  assert.throws(() => swapCase(42), TypeError);
  assert.throws(() => swapCase(null), TypeError);
  assert.throws(() => swapCase(undefined), TypeError);
});
