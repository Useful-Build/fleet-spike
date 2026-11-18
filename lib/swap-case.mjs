// Swaps the case of every letter: upper case becomes lower case and lower case becomes upper case.
export function swapCase(text) {
  if (typeof text !== "string") {
    throw new TypeError(`swapCase expects a string, got ${text === null ? "null" : typeof text}`);
  }
  let out = "";
  for (const ch of text) {
    const upper = ch.toUpperCase();
    out += ch === upper ? ch.toLowerCase() : upper;
  }
  return out;
}
