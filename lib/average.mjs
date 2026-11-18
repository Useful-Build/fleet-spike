// Returns the arithmetic mean of an array of numbers.
export function average(numbers) {
  if (!Array.isArray(numbers)) throw new TypeError("numbers must be an array");
  if (numbers.length === 0) throw new RangeError("numbers must not be empty");
  let sum = 0;
  for (const n of numbers) {
    if (typeof n !== "number") throw new TypeError("numbers must hold only numbers");
    sum += n;
  }
  return sum / numbers.length;
}
