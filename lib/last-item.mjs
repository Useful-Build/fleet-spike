// Returns the last value of the array items.
export function lastItem(items) {
  if (!Array.isArray(items)) throw new TypeError("items must be an array");
  if (items.length === 0) throw new RangeError("items must not be empty");
  return items[items.length - 1];
}
