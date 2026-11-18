// Returns text with every space, tab and newline (\n or \r\n) removed.
export function stripSpaces(text) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  return text.replace(/[ \t\r\n]/g, "");
}
