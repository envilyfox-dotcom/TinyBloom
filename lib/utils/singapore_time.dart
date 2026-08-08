/// TinyBloom runs on Singapore time. Singapore doesn't observe daylight
/// saving, so a fixed +8h offset is correct year-round and no full timezone
/// package is needed.
///
/// Two different kinds of `DateTime` flow through this app, and mixing them
/// is exactly the bug this file exists to prevent:
///
///  * **Instants** — an absolute point in time, independent of where you're
///    standing. This is what a Postgres `timestamptz` column stores
///    (`created_at`, `read_at`, `rescheduled_at`, `call_requested_at`).
///    Always write these with [dbNow] / [dbTimestamp], which emit UTC with
///    an explicit `Z`. Dart's plain `DateTime.now().toIso8601String()`
///    produces a *naive* string with no zone marker, which Postgres then
///    reads as UTC — silently shifting the value 8 hours forward.
///
///  * **Singapore wall clock** — the date and time a person in Singapore
///    reads off a clock. Carried in a `DateTime` whose fields are already
///    SGT and whose `isUtc` flag is true, so `DateFormat` and `.hour` print
///    them verbatim instead of re-shifting into the device's timezone.
///    Produced by [toSingaporeTime], [sgtNow] and [sgtWallClock].
///
/// The rule: never compare or format a raw `DateTime.now()` against a value
/// that came out of the database. Convert both into one frame first.
///
/// Wall-clock values that were never instants in the first place — a date
/// picked from a calendar, a `date` column like `scheduled_date` — are
/// already in the wall-clock frame. Pass those to [dateOnly] as-is; do not
/// run them through [toSingaporeTime], or you'll shift them by a day.
library;

import 'package:intl/intl.dart';

const singaporeOffset = Duration(hours: 8);

/// "Now" as an absolute instant, ready for a `timestamptz` column.
///
/// Use this for every explicit timestamp write. Where the column already
/// has a `default now()`, prefer omitting the field entirely and letting
/// Postgres fill it — the server clock beats a device clock that may be
/// skewed or deliberately wrong.
String dbNow() => DateTime.now().toUtc().toIso8601String();

/// Converts any instant into the UTC form a `timestamptz` column expects.
String dbTimestamp(DateTime instant) => instant.toUtc().toIso8601String();

/// Shifts an instant into Singapore wall-clock fields for display.
///
/// The result is flagged UTC so `DateFormat` prints the SGT fields as-is.
/// It is a display value only — never write it back to the database.
DateTime toSingaporeTime(DateTime date) => date.toUtc().add(singaporeOffset);

/// The current Singapore wall-clock time.
///
/// Use this instead of `DateTime.now()` for any comparison against a
/// booking slot or a value from the database.
DateTime sgtNow() => toSingaporeTime(DateTime.now());

/// Parses a `timestamptz` value from Supabase into Singapore wall clock,
/// or null if it's missing or unparseable.
DateTime? sgtFrom(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return toSingaporeTime(raw);
  final parsed = DateTime.tryParse(raw.toString());
  return parsed == null ? null : toSingaporeTime(parsed);
}

/// Parses a `date` column (`due_date`, `scheduled_date`, `log_date`) into
/// the Singapore wall-clock frame.
///
/// Unlike [sgtFrom] this does no shifting: a `date` carries no timezone, so
/// its calendar fields are already wall clock and only need re-tagging.
/// Using [sgtFrom] here instead would move the day by 8 hours.
DateTime? sgtDateFrom(dynamic raw) {
  if (raw == null) return null;
  final parsed = raw is DateTime ? raw : DateTime.tryParse(raw.toString());
  return parsed == null ? null : asSgtWallClock(parsed);
}

/// Builds a Singapore wall-clock `DateTime` from calendar fields — the
/// counterpart to the plain `DateTime(...)` constructor, which would tag
/// the result with the device's timezone instead.
DateTime sgtWallClock(int year, int month, int day,
        [int hour = 0, int minute = 0]) =>
    DateTime.utc(year, month, day, hour, minute);

/// Re-tags a wall-clock `DateTime` that was built with the local-time
/// constructor (a date picker's result, say) into the Singapore frame,
/// keeping its calendar fields exactly as they are.
DateTime asSgtWallClock(DateTime wallClock) => DateTime.utc(
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
    );

/// The calendar date only, formatted for a Postgres `date` column.
///
/// Takes a value already in the wall-clock frame — a picked date, or the
/// result of [sgtNow]. It reads the fields directly and does no shifting,
/// so the day can't slide either side of midnight.
String dateOnly(DateTime wallClock) =>
    DateFormat('yyyy-MM-dd').format(wallClock);

/// Today's date in Singapore, formatted for a `date` column.
String sgtToday() => dateOnly(sgtNow());
