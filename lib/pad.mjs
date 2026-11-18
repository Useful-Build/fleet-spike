// Returns text padded on the left with fill to width characters, unchanged when already that long.
export function padLeft(text, width, fill = " ") {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  return text.padStart(width, fill);
}
