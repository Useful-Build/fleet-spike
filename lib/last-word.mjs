// Returns the last whitespace-separated word of text, or "" when there is none.
export function lastWord(text) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  const words = text.trim().split(/\s+/);
  return words[words.length - 1];
}
