// Returns the absolute difference of the numbers a and b.
export function absDiff(a, b) {
  if (typeof a !== "number" || typeof b !== "number") {
    throw new TypeError("a and b must be numbers");
  }
  return Math.abs(a - b);
}
