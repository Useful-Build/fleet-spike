// The largest value in `numbers`. Throws a TypeError on a non-array or a non-number entry,
// and a RangeError on an empty array.
export function maxOf(numbers) {
  if (!Array.isArray(numbers)) throw new TypeError("maxOf needs an array");
  if (numbers.length === 0) throw new RangeError("maxOf needs at least one number");
  let max = -Infinity;
  for (const [i, n] of numbers.entries()) {
    if (typeof n !== "number") throw new TypeError(`entry ${i} is not a number`);
    if (n > max || Number.isNaN(n)) max = n; // NaN wins and stays, like Math.max
  }
  return max;
}
