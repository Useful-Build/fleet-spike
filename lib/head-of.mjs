// Returns the first value of the array items.
export function headOf(items) {
  if (!Array.isArray(items)) throw new TypeError("items must be an array");
  if (items.length === 0) throw new RangeError("items must not be empty");
  return items[0];
}
