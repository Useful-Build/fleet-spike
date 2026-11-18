// Returns true when n is greater than 0.
export function isPositive(n) {
  if (typeof n !== "number" || Number.isNaN(n)) throw new TypeError("n must be a number");
  return n > 0;
}
