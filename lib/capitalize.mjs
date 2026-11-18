// Returns text with its first character in upper case and the rest unchanged.
export function capitalize(text) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  const [first = ""] = text;
  return first.toUpperCase() + text.slice(first.length);
}
