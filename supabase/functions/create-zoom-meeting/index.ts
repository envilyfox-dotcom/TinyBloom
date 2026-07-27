declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
  serve(
    handler: (req: Request) => Response | Promise<Response>,
  ): void;
};

// Approving a specialist consultation used to just flip its status to
// 'confirmed' while the app had already stuffed a fake, non-functional
// "https://zoom.us/j/<timestamp>" string into meeting_link at booking time
// (see confirm_consultation_screen.dart). Nothing behind that link ever
// existed, so nobody could actually join. This function replaces that:
// on approval, it creates a real Zoom meeting via a Server-to-Server OAuth
// app and stores the genuine join_url, so the link both sides get is one
// that actually exists at the scheduled time.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// The whole app treats scheduled_date/scheduled_time as Singapore wall-clock
// time with no DST (see lib/utils/singapore_time.dart) — Zoom is simply told
// the same local time plus that fixed IANA zone, rather than converting to UTC.
const MEETING_TIMEZONE = "Asia/Singapore";
const MEETING_DURATION_MINUTES = 30;

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

// Accepts the same time formats the app already uses when a mum books a
// slot ("3:00 PM", "3 PM", "15:00", "3:00") and returns 24h "HH:mm", or
// null if it can't be parsed.
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

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = safeString(Deno.env.get("SUPABASE_URL"));
  const anonKey = safeString(Deno.env.get("SUPABASE_ANON_KEY"));
  const zoomAccountId = safeString(Deno.env.get("ZOOM_ACCOUNT_ID"));
  const zoomClientId = safeString(Deno.env.get("ZOOM_CLIENT_ID"));
  const zoomClientSecret = safeString(Deno.env.get("ZOOM_CLIENT_SECRET"));

  if (!supabaseUrl || !anonKey) {
    return jsonResponse(
      { error: "Supabase credentials are not configured." },
      500,
    );
  }

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

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) {
    return jsonResponse({ error: "Missing Authorization header." }, 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_error) {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  const consultationId = safeString(body.consultation_id);
  if (!consultationId) {
    return jsonResponse({ error: "Missing consultation_id." }, 400);
  }

  // Forwarding the caller's own JWT (rather than the service role key) means
  // this read is scoped by RLS: a specialist can only ever fetch a
  // consultation that's actually theirs, so there's no separate ownership
  // check to get wrong here.
  const consultationRes = await fetch(
    `${supabaseUrl}/rest/v1/consultations?id=eq.${consultationId}&select=id,status,scheduled_date,scheduled_time,purpose`,
    {
      headers: {
        apikey: anonKey,
        Authorization: authHeader,
      },
    },
  );

  if (!consultationRes.ok) {
    return jsonResponse(
      { error: "Could not look up the consultation.", details: await consultationRes.text() },
      500,
    );
  }

  const rows = await consultationRes.json();
  const consultation = Array.isArray(rows) ? rows[0] : null;

  if (!consultation) {
    return jsonResponse(
      { error: "Consultation not found, or you don't have permission to approve it." },
      404,
    );
  }

  if (consultation.status !== "pending") {
    return jsonResponse(
      { error: `Consultation is '${consultation.status}', not 'pending'.` },
      409,
    );
  }

  const scheduledDate = safeString(consultation.scheduled_date);
  const scheduledTime24h = parseTimeTo24h(safeString(consultation.scheduled_time));

  if (!scheduledDate || !scheduledTime24h) {
    return jsonResponse(
      { error: "Consultation is missing a valid scheduled date/time." },
      422,
    );
  }

  const startTime = `${scheduledDate}T${scheduledTime24h}:00`;
  const topic = safeString(consultation.purpose) || "TinyBloom Specialist Consultation";

  // Server-to-Server OAuth: exchange the app's credentials for a short-lived
  // access token scoped to this Zoom account (no user ever visits a Zoom
  // consent screen, unlike the regular OAuth flow).
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
      type: 2, // scheduled meeting
      start_time: startTime,
      timezone: MEETING_TIMEZONE,
      duration: MEETING_DURATION_MINUTES,
      settings: {
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

  // Same forwarded JWT for the write: the specialist-update RLS policy
  // (specialist_id = auth.uid()) is what actually authorises this.
  const updateRes = await fetch(
    `${supabaseUrl}/rest/v1/consultations?id=eq.${consultationId}`,
    {
      method: "PATCH",
      headers: {
        apikey: anonKey,
        Authorization: authHeader,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: JSON.stringify({
        status: "confirmed",
        platform: "Zoom Meeting",
        meeting_link: meetingData.join_url,
      }),
    },
  );

  if (!updateRes.ok) {
    return jsonResponse(
      { error: "Zoom meeting was created but saving it failed.", details: await updateRes.text() },
      500,
    );
  }

  const updated = await updateRes.json();
  const updatedRow = Array.isArray(updated) ? updated[0] : null;

  if (!updatedRow) {
    return jsonResponse(
      { error: "Could not confirm this consultation — you may not have permission to." },
      403,
    );
  }

  return jsonResponse({
    status: "confirmed",
    meeting_link: meetingData.join_url,
    zoom_meeting_id: meetingData.id,
  });
});
