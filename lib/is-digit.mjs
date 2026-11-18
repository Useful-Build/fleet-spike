// Returns true when char is a single digit 0 to 9.
export function isDigit(char) {
  if (typeof char !== "string" || char.length !== 1) {
    throw new TypeError("char must be a one character string");
  }
  return char >= "0" && char <= "9";
}
