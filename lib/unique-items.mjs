// Returns a new array with the values of items in first-seen order, without repeats.
export function uniqueItems(items) {
  if (!Array.isArray(items)) throw new TypeError("items must be an array");
  return [...new Set(items)];
}
