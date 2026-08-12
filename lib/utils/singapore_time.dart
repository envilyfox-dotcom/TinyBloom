// TinyBloom runs on Singapore time. Singapore has no daylight saving, so a
// plain +8h offset is correct all year and we don't need a full timezone
// package for this.
//
// The thing to watch out for: there are two different kinds of DateTime
// floating around this app, and mixing them up is a real bug we've hit.
//
// 1. "Instants" - an absolute point in time, e.g. what a Postgres
//    `timestamptz` column stores (created_at, read_at, etc). Always write
//    these using dbNow() / dbTimestamp(), which output UTC with a `Z` on
//    the end. If you just do DateTime.now().toIso8601String() instead, it
//    has no zone marker, so Postgres assumes it's already UTC and the time
//    silently jumps 8 hours forward.
//
// 2. "Singapore wall clock" - the date/time you'd actually read off a clock
//    in Singapore. This is a DateTime whose fields are SGT but whose
//    `isUtc` flag is set to true, purely as a trick so DateFormat/.hour
//    print it as-is instead of trying to re-shift it into the device's own
//    timezone. Produced by toSingaporeTime(), sgtNow(), sgtWallClock().
//
// Golden rule: never compare/format a raw DateTime.now() straight against
// something that came out of the database - convert both to the same frame
// first (usually via sgtNow() and sgtFrom()).
//
// One more gotcha: plain `date` columns (scheduled_date, due_date, etc)
// were never instants to begin with, so they're already wall-clock values.
// Pass those to dateOnly() as-is - don't run them through toSingaporeTime()
// or you'll shift the date by a day.
library;

import 'package:intl/intl.dart';

const singaporeOffset = Duration(hours: 8);

// "Now" as an absolute instant, ready to write to a timestamptz column.
// If the column already has `default now()` in Postgres, prefer just
// omitting the field and letting the server fill it in - the server clock
// is more trustworthy than a device clock that could be wrong or skewed.
String dbNow() => DateTime.now().toUtc().toIso8601String();

// Converts any instant into the UTC string a timestamptz column expects.
String dbTimestamp(DateTime instant) => instant.toUtc().toIso8601String();

// Shifts an instant into Singapore wall-clock fields, for display only -
// never write this back to the database.
DateTime toSingaporeTime(DateTime date) => date.toUtc().add(singaporeOffset);

// The current time, as Singapore wall clock. Use this instead of
// DateTime.now() whenever comparing against a booking slot or a db value.
DateTime sgtNow() => toSingaporeTime(DateTime.now());

// Parses a timestamptz value from Supabase into Singapore wall clock, or
// null if it's missing/unparseable.
DateTime? sgtFrom(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return toSingaporeTime(raw);
  final parsed = DateTime.tryParse(raw.toString());
  return parsed == null ? null : toSingaporeTime(parsed);
}

// Parses a plain `date` column (due_date, scheduled_date, log_date) into
// the wall-clock frame. Unlike sgtFrom, this doesn't shift anything - a
// `date` has no timezone so its fields are already wall clock and just need
// re-tagging. Using sgtFrom here by mistake would move the day by 8 hours.
DateTime? sgtDateFrom(dynamic raw) {
  if (raw == null) return null;
  final parsed = raw is DateTime ? raw : DateTime.tryParse(raw.toString());
  return parsed == null ? null : asSgtWallClock(parsed);
}

// Builds a Singapore wall-clock DateTime straight from calendar fields -
// use this instead of the plain DateTime(...) constructor, which would tag
// the result with the device's own timezone instead of SGT.
DateTime sgtWallClock(int year, int month, int day,
        [int hour = 0, int minute = 0]) =>
    DateTime.utc(year, month, day, hour, minute);

// Re-tags a wall-clock DateTime that was built with the local-time
// constructor (e.g. straight out of a date picker) into the Singapore
// frame, keeping the calendar fields exactly as they are.
DateTime asSgtWallClock(DateTime wallClock) => DateTime.utc(
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
    );

// Formats just the calendar date for a Postgres `date` column. Expects a
// value already in the wall-clock frame (a picked date, or sgtNow()) and
// reads the fields directly with no shifting, so the day can't slide.
String dateOnly(DateTime wallClock) =>
    DateFormat('yyyy-MM-dd').format(wallClock);

// Today's date in Singapore, formatted for a `date` column.
String sgtToday() => dateOnly(sgtNow());
