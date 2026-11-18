// Sum of an array of numbers. Throws a TypeError on a non-array or a non-number item.
export function sumList(numbers) {
  if (!Array.isArray(numbers)) {
    throw new TypeError("sumList expects an array");
  }
  let total = 0;
  for (const n of numbers) {
    if (typeof n !== "number") {
      throw new TypeError(`sumList expects numbers, got ${typeof n}`);
    }
    total += n;
  }
  return total;
}
