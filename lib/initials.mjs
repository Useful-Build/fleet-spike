// Returns the upper-cased first letter of each word, joined with no separator.
export function initials(name) {
  if (typeof name !== "string") throw new TypeError("name must be a string");
  return name
    .split(/\s+/)
    .filter(Boolean)
    .map((word) => word[0].toUpperCase())
    .join("");
}
