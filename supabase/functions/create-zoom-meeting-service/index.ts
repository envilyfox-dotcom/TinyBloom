declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
  serve(
    handler: (req: Request) => Response | Promise<Response>,
  ): void;
};

// Publishing a volunteer service listing used to require the volunteer to
// go create a Zoom meeting themselves and paste the link in by hand. This
// creates a real, open-to-anyone Zoom meeting for the listing's slot
// instead, the same way approving a specialist consultation or accepting a
// volunteer video call now does (see the other create-zoom-meeting*
// functions) — except a service listing has no counterparty to wait on, so
// this is called directly when the volunteer hits Publish, with no
// database row to read or write: it just mints a meeting and hands back
// the join_url for the client to save.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MEETING_TIMEZONE = "Asia/Singapore";
const DEFAULT_DURATION_MINUTES = 60;

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function safeString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

// Same time-format handling as the other create-zoom-meeting* functions
// ("3:00 PM", "3 PM", "15:00", "3:00").
function parseTimeTo24h(raw: string): string | null {
  const cleaned = raw.trim().toUpperCase().replace(/\./g, "");

  let match = cleaned.match(/^(\d{1,2}):(\d{2})\s*(AM|PM)?$/);
  if (match) {
    let hour = parseInt(match[1], 10);
    const minute = parseInt(match[2], 10);
    const meridiem = match[3];
    if (meridiem === "PM" && hour !== 12) hour += 12;
    if (meridiem === "AM" && hour === 12) hour = 0;
    if (hour > 23 || minute > 59) return null;
    return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
  }

  match = cleaned.match(/^(\d{1,2})\s*(AM|PM)$/);
  if (match) {
    let hour = parseInt(match[1], 10);
    const meridiem = match[2];
    if (meridiem === "PM" && hour !== 12) hour += 12;
    if (meridiem === "AM" && hour === 12) hour = 0;
    if (hour > 23) return null;
    return `${String(hour).padStart(2, "0")}:00`;
  }

  return null;
}

function minutesSinceMidnight(hhmm: string): number {
  const [h, m] = hhmm.split(":").map((n) => parseInt(n, 10));
  return h * 60 + m;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const zoomAccountId = safeString(Deno.env.get("ZOOM_ACCOUNT_ID"));
  const zoomClientId = safeString(Deno.env.get("ZOOM_CLIENT_ID"));
  const zoomClientSecret = safeString(Deno.env.get("ZOOM_CLIENT_SECRET"));

  if (!zoomAccountId || !zoomClientId || !zoomClientSecret) {
    return jsonResponse(
      {
        error: "Zoom secrets are not configured.",
        missing: {
          ZOOM_ACCOUNT_ID: !zoomAccountId,
          ZOOM_CLIENT_ID: !zoomClientId,
          ZOOM_CLIENT_SECRET: !zoomClientSecret,
        },
      },
      500,
    );
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_error) {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  const date = safeString(body.date);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return jsonResponse({ error: "Missing or invalid date (expected YYYY-MM-DD)." }, 400);
  }

  const startTime24h = parseTimeTo24h(safeString(body.start_time));
  if (!startTime24h) {
    return jsonResponse({ error: "Missing or invalid start_time." }, 400);
  }

  const endTime24h = parseTimeTo24h(safeString(body.end_time));
  const duration = endTime24h &&
      minutesSinceMidnight(endTime24h) > minutesSinceMidnight(startTime24h)
    ? minutesSinceMidnight(endTime24h) - minutesSinceMidnight(startTime24h)
    : DEFAULT_DURATION_MINUTES;

  const rawTitle = safeString(body.title);
  const topic = rawTitle.length > 0
    ? `TinyBloom Service: ${rawTitle.slice(0, 175)}`
    : "TinyBloom Volunteer Service Session";

  const startTime = `${date}T${startTime24h}:00`;

  const tokenRes = await fetch(
    `https://zoom.us/oauth/token?grant_type=account_credentials&account_id=${encodeURIComponent(zoomAccountId)}`,
    {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${zoomClientId}:${zoomClientSecret}`)}`,
      },
    },
  );

  const tokenData = await tokenRes.json();

  if (!tokenRes.ok || !tokenData.access_token) {
    return jsonResponse(
      { error: "Zoom authentication failed.", details: tokenData },
      502,
    );
  }

  const meetingRes = await fetch("https://api.zoom.us/v2/users/me/meetings", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${tokenData.access_token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      topic,
      type: 2,
      start_time: startTime,
      timezone: MEETING_TIMEZONE,
      duration,
      settings: {
        // Anyone with the link can join — there's no single counterparty
        // to admit, unlike a 1:1 consultation or call.
        join_before_host: true,
        waiting_room: false,
        approval_type: 2,
        mute_upon_entry: true,
      },
    }),
  });

  const meetingData = await meetingRes.json();

  if (!meetingRes.ok || !meetingData.join_url) {
    return jsonResponse(
      { error: "Creating the Zoom meeting failed.", details: meetingData },
      502,
    );
  }

  return jsonResponse({
    meeting_link: meetingData.join_url,
    zoom_meeting_id: meetingData.id,
  });
});
