import { test } from "node:test";
import assert from "node:assert/strict";
import { isPalindrome } from "../lib/is-palindrome.mjs";

test("a palindrome reads the same backwards", () => {
  assert.equal(isPalindrome("racecar"), true);
});

test("a non-palindrome is not a palindrome", () => {
  assert.equal(isPalindrome("hello"), false);
});

test("ignores mixed case and spaces", () => {
  assert.equal(isPalindrome("Never Odd Or Even"), true);
});

test("an empty string is a palindrome", () => {
  assert.equal(isPalindrome(""), true);
});

test("rejects a non-string", () => {
  assert.throws(() => isPalindrome(121), TypeError);
  assert.throws(() => isPalindrome(null), TypeError);
  assert.throws(() => isPalindrome(undefined), TypeError);
});
