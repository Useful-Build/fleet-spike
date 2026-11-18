// Counts the vowels a, e, i, o and u in text, upper or lower case.
export function countVowels(text) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  return (text.match(/[aeiou]/gi) ?? []).length;
}
