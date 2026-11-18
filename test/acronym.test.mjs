import { test } from "node:test";
import assert from "node:assert/strict";
import { acronym } from "../lib/acronym.mjs";

test("joins the first letters of three long words", () => {
  assert.equal(acronym("graphics interchange format"), "GIF");
});

test("skips words of two characters or fewer", () => {
  assert.equal(acronym("portable network of graphics"), "PNG");
});

test("handles extra whitespace between and around words", () => {
  assert.equal(acronym("  portable \t network\n\n graphics  "), "PNG");
});

test("returns an empty string for an empty string", () => {
  assert.equal(acronym(""), "");
});

test("rejects a non-string", () => {
  assert.throws(() => acronym(42), TypeError);
});
