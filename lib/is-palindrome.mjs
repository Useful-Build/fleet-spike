// Returns true when text reads the same backwards, ignoring case and spaces.
export function isPalindrome(text) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  const letters = [...text.toLowerCase().replaceAll(" ", "")];
  return letters.join("") === letters.reverse().join("");
}
