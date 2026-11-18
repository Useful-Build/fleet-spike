// Returns a new array with every number in numbers multiplied by 2.
export function doubleAll(numbers) {
  if (!Array.isArray(numbers)) throw new TypeError("numbers must be an array");
  return numbers.map((n) => {
    if (typeof n !== "number") throw new TypeError("every value must be a number");
    return n * 2;
  });
}
