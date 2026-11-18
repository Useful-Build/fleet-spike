// Returns value limited to the range min to max.
export function clamp(value, min, max) {
  for (const [name, arg] of [["value", value], ["min", min], ["max", max]]) {
    if (typeof arg !== "number" || Number.isNaN(arg)) throw new TypeError(`${name} must be a number`);
  }
  if (min > max) throw new RangeError("min must not be greater than max");
  return Math.min(Math.max(value, min), max);
}
