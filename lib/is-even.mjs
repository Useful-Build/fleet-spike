// True when the integer n is even. Anything that isn't an integer throws.
export function isEven(n) {
  if (!Number.isInteger(n)) throw new TypeError("n must be an integer");
  return n % 2 === 0;
}
