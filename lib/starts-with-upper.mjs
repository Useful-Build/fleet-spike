// Returns true when the first character of text is an upper case letter, else false.
export function startsWithUpper(text) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  return /^\p{Lu}/u.test(text);
}
