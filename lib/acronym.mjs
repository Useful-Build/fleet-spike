// Returns the upper case first letters of the words longer than two characters.
export function acronym(text) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  return text
    .split(/\s+/)
    .filter((word) => word.length > 2)
    .map((word) => word[0].toUpperCase())
    .join("");
}
