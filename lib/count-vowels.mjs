// Counts the letters a, e, i, o and u in a string, upper or lower case.
export function countVowels(text) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  return (text.match(/[aeiou]/gi) ?? []).length;
}
