import { readFileSync } from "node:fs";
import { slugify } from "./slug.mjs";

export function loadRegistry(registryPath, totalPath) {
  const entries = JSON.parse(readFileSync(registryPath, "utf8"));
  const total = Number(readFileSync(totalPath, "utf8").trim());
  return { entries, total };
}

// Every way the registry can be wrong, as a list of messages. Empty means valid.
export function checkRegistry(entries, total) {
  const errors = [];
  if (!Array.isArray(entries)) return ["registry must be a JSON array"];
  const seen = new Set();
  for (const [i, entry] of entries.entries()) {
    if (typeof entry?.id !== "string" || typeof entry?.name !== "string") {
      errors.push(`entry ${i} needs a string id and name`);
      continue;
    }
    if (entry.id !== slugify(entry.name)) {
      errors.push(`entry ${i}: id "${entry.id}" should be "${slugify(entry.name)}"`);
    }
    if (seen.has(entry.id)) errors.push(`duplicate id "${entry.id}"`);
    seen.add(entry.id);
  }
  if (!Number.isInteger(total)) errors.push("TOTAL must hold a whole number");
  else if (total !== entries.length) {
    errors.push(`TOTAL says ${total} but the registry has ${entries.length} entries`);
  }
  return errors;
}
