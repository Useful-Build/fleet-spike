// True when text reads the same backwards, ignoring case and spaces. An empty string is a palindrome.
export function isPalindrome(text) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  const chars = [...text.toLowerCase().replace(/\s+/g, "")];
  return chars.join("") === chars.reverse().join("");
}
