import { test } from "node:test";
import assert from "node:assert/strict";
import { isLeapYear } from "../lib/is-leap-year.mjs";

test("2024 is a leap year", () => {
  assert.equal(isLeapYear(2024), true);
});

test("2023 is not a leap year", () => {
  assert.equal(isLeapYear(2023), false);
});

test("1900 is not a leap year", () => {
  assert.equal(isLeapYear(1900), false);
});

test("2000 is a leap year", () => {
  assert.equal(isLeapYear(2000), true);
});

test("throws a TypeError for a non-integer", () => {
  assert.throws(() => isLeapYear(2024.5), TypeError);
  assert.throws(() => isLeapYear("2024"), TypeError);
});
