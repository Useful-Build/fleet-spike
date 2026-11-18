// Turns a display name into a registry id: lower case, words joined by single dashes.
export function slugify(name) {
  if (typeof name !== "string") throw new TypeError("name must be a string");
  return name
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}
