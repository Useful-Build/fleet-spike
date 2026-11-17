import { test } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { checkRegistry, loadRegistry } from "../lib/registry.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));

test("finds duplicate ids and a wrong TOTAL", () => {
  const entries = [
    { id: "alpha", name: "Alpha" },
    { id: "alpha", name: "Alpha" },
  ];
  assert.deepEqual(checkRegistry(entries, 3), [
    'duplicate id "alpha"',
    "TOTAL says 3 but the registry has 2 entries",
  ]);
});

test("finds an id that doesn't match its name", () => {
  assert.deepEqual(checkRegistry([{ id: "x", name: "Alpha" }], 1), [
    'entry 0: id "x" should be "alpha"',
  ]);
});

// The repo's own registry. Two branches that each add one entry and bump TOTAL by one pass
// alone and fail together, which is how the merge queue's drop-and-repair path gets tested.
test("registry.json and TOTAL agree", () => {
  const { entries, total } = loadRegistry(`${root}registry.json`, `${root}TOTAL`);
  assert.deepEqual(checkRegistry(entries, total), []);
});
