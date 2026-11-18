// Joins the strings in items with separator between them, or returns "" for an empty array.
export function joinWith(items, separator) {
  if (!Array.isArray(items)) throw new TypeError("items must be an array");
  if (!items.every((item) => typeof item === "string")) throw new TypeError("every item must be a string");
  if (typeof separator !== "string") throw new TypeError("separator must be a string");
  return items.join(separator);
}
