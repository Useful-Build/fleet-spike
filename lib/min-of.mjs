// Returns the smallest value in the array numbers.
export function minOf(numbers) {
  if (!Array.isArray(numbers)) throw new TypeError("numbers must be an array");
  for (const n of numbers) {
    if (typeof n !== "number" || Number.isNaN(n)) throw new TypeError("numbers must hold only numbers");
  }
  if (numbers.length === 0) throw new RangeError("numbers must not be empty");
  return numbers.reduce((min, n) => (n < min ? n : min));
}
