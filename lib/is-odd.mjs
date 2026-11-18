// Returns true when the integer n is odd.
export function isOdd(n) {
  if (!Number.isInteger(n)) throw new TypeError("n must be an integer");
  return n % 2 !== 0;
}
