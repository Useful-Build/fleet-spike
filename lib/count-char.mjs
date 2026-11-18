// How many times the one character string `char` appears in `text`.
export function countChar(text, char) {
  if (typeof text !== "string") throw new TypeError("text must be a string");
  if (typeof char !== "string" || char.length !== 1) {
    throw new TypeError("char must be a one character string");
  }
  let count = 0;
  for (const c of text) if (c === char) count++;
  return count;
}
