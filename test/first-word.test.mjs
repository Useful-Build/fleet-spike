import { test } from "node:test";
import assert from "node:assert/strict";
import { firstWord } from "../lib/first-word.mjs";

test("firstWord: one word", () => {
  assert.equal(firstWord("hello"), "hello");
});

test("firstWord: three words", () => {
  assert.equal(firstWord("alpha beta gamma"), "alpha");
});

test("firstWord: leading spaces", () => {
  assert.equal(firstWord("  \t\n alpha beta"), "alpha");
});

test("firstWord: empty string", () => {
  assert.equal(firstWord(""), "");
});

test("firstWord: non-string throws a TypeError", () => {
  assert.throws(() => firstWord(42), TypeError);
});
