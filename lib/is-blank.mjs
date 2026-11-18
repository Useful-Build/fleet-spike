// Returns true when text is empty or only whitespace.
export function isBlank(text) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  return text.trim() === "";
}
