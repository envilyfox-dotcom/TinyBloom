// Converts any DateTime (UTC-aware, from a parsed Supabase timestamptz, or
// a naive local DateTime.now()) into its Singapore-time (GMT+8) equivalent
// for display. Singapore doesn't observe daylight saving, so a fixed +8h
// offset is correct year-round — no need for a full timezone package.
DateTime toSingaporeTime(DateTime date) =>
    date.toUtc().add(const Duration(hours: 8));
