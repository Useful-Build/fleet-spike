import { test } from "node:test";
import assert from "node:assert/strict";
import { stripDigits } from "../lib/strip-digits.mjs";

test("stripDigits removes every digit from text with digits", () => {
  assert.equal(stripDigits("a1b22c 3-4.5x9 0"), "abc -.x ");
});

test("stripDigits leaves text without digits unchanged", () => {
  assert.equal(stripDigits("no digits here, ¹²³ or ٣ either"), "no digits here, ¹²³ or ٣ either");
});

test("stripDigits turns only digits into an empty string", () => {
  assert.equal(stripDigits("0123456789"), "");
});

test("stripDigits keeps an empty string empty", () => {
  assert.equal(stripDigits(""), "");
});

test("stripDigits throws a TypeError for a non-string", () => {
  for (const value of [123, null, undefined, ["1"], { toString: () => "1" }]) {
    assert.throws(() => stripDigits(value), TypeError);
  }
});
