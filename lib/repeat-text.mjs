// Joins text to itself times times, or returns "" when times is 0.
export function repeatText(text, times) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  if (!Number.isInteger(times) || times < 0) throw new RangeError("times must be a whole number of 0 or more");
  return text.repeat(times);
}
