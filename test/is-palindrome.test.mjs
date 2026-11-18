import { test } from "node:test";
import assert from "node:assert/strict";
import { isPalindrome } from "../lib/is-palindrome.mjs";

test("isPalindrome: a palindrome is true", () => {
  assert.equal(isPalindrome("racecar"), true);
});

test("isPalindrome: a non-palindrome is false", () => {
  assert.equal(isPalindrome("palindrome"), false);
});

test("isPalindrome: ignores mixed case and spaces", () => {
  assert.equal(isPalindrome("Never Odd Or Even"), true);
});

test("isPalindrome: an empty string is true", () => {
  assert.equal(isPalindrome(""), true);
});

test("isPalindrome: a non-string throws a TypeError", () => {
  assert.throws(() => isPalindrome(12321), TypeError);
  assert.throws(() => isPalindrome(null), TypeError);
});
