// Returns true when text ends with a ".", else false.
export function endsWithDot(text) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  return text.endsWith(".");
}
