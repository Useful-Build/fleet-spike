// Adds fill to the right of text until it is width characters long; longer text is returned unchanged.
export function padRight(text, width, fill) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  if (typeof fill !== "string" || fill.length !== 1) throw new TypeError("fill must be a one character string");
  return text.padEnd(width, fill);
}
