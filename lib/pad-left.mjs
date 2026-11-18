// `text` with `fill` added on the left until it is `width` characters long.
export function padLeft(text, width, fill) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  if (typeof fill !== "string" || fill.length !== 1) {
    throw new TypeError("fill must be a one character string");
  }
  return text.padStart(width, fill);
}
