// Returns true when year is a leap year in the Gregorian calendar.
export function isLeapYear(year) {
  if (!Number.isInteger(year)) throw new TypeError("year must be an integer");
  return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
}
