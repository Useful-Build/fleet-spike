// Returns items split into arrays of size values, the last one shorter when needed.
export function chunkList(items, size) {
  if (!Array.isArray(items)) throw new TypeError("items must be an array");
  if (!Number.isInteger(size) || size < 1) throw new RangeError("size must be an integer of at least 1");
  const chunks = [];
  for (let i = 0; i < items.length; i += size) chunks.push(items.slice(i, i + size));
  return chunks;
}
