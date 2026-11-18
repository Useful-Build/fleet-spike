// Returns the words of text in reverse order, joined by single spaces.
export function reverseWords(text) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  return text.split(" ").filter(Boolean).reverse().join(" ");
}
