// Removes every ASCII digit 0 to 9 from text.
export function stripDigits(text) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  return text.replace(/[0-9]/g, "");
}
