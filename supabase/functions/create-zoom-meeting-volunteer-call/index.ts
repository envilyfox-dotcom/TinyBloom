declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
  serve(
    handler: (req: Request) => Response | Promise<Response>,
  ): void;
};

// Mirrors supabase/functions/create-zoom-meeting, but for the volunteer
// Q&A board's video calls (volunteer_requests table) instead of specialist
// consultations. Previously, once a mum accepted a volunteer's proposed
// call time, the volunteer had to go create a Zoom meeting themselves and
// paste the invite in by hand. This creates a real Zoom meeting the moment
// the mum accepts, so there's nothing left to paste.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Same fixed, DST-free Singapore offset the rest of the app assumes for
// scheduled_date/scheduled_time — see lib/utils/singapore_time.dart.
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

// Accepts the same time formats the app already uses for a proposed call
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

  const requestId = safeString(body.request_id);
  if (!requestId) {
    return jsonResponse({ error: "Missing request_id." }, 400);
  }

  // Forwarding the mum's own JWT scopes this by RLS — she can only ever
  // fetch a volunteer_requests row she's actually party to.
  const requestRes = await fetch(
    `${supabaseUrl}/rest/v1/volunteer_requests?id=eq.${requestId}&select=id,call_status,scheduled_date,scheduled_time,question`,
    {
      headers: {
        apikey: anonKey,
        Authorization: authHeader,
      },
    },
  );

  if (!requestRes.ok) {
    return jsonResponse(
      { error: "Could not look up the video call request.", details: await requestRes.text() },
      500,
    );
  }

  const rows = await requestRes.json();
  const volunteerRequest = Array.isArray(rows) ? rows[0] : null;

  if (!volunteerRequest) {
    return jsonResponse(
      { error: "Request not found, or you don't have permission to accept it." },
      404,
    );
  }

  if (volunteerRequest.call_status !== "requested") {
    return jsonResponse(
      { error: `Video call is '${volunteerRequest.call_status}', not 'requested'.` },
      409,
    );
  }

  const scheduledDate = safeString(volunteerRequest.scheduled_date);
  const scheduledTime24h = parseTimeTo24h(safeString(volunteerRequest.scheduled_time));

  if (!scheduledDate || !scheduledTime24h) {
    return jsonResponse(
      { error: "This call request is missing a valid scheduled date/time." },
      422,
    );
  }

  const startTime = `${scheduledDate}T${scheduledTime24h}:00`;
  const rawTopic = safeString(volunteerRequest.question);
  const topic = rawTopic.length > 0
    ? `TinyBloom Volunteer Call: ${rawTopic.slice(0, 150)}`
    : "TinyBloom Volunteer Video Call";

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

  const updateRes = await fetch(
    `${supabaseUrl}/rest/v1/volunteer_requests?id=eq.${requestId}`,
    {
      method: "PATCH",
      headers: {
        apikey: anonKey,
        Authorization: authHeader,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: JSON.stringify({
        call_status: "accepted",
        meeting_link: meetingData.join_url,
      }),
    },
  );

  if (!updateRes.ok) {
    const updateError = await updateRes.json().catch(() => null);
    // Same partial-unique-index conflict the old direct-update path could
    // hit: the volunteer already has another accepted call at this exact
    // slot.
    if (updateError?.code === "23505") {
      return jsonResponse(
        {
          error:
            "Your volunteer already has another call accepted at that time. Ask them to propose a different slot.",
        },
        409,
      );
    }
    return jsonResponse(
      { error: "Zoom meeting was created but saving it failed.", details: updateError ?? await updateRes.text() },
      500,
    );
  }

  const updated = await updateRes.json();
  const updatedRow = Array.isArray(updated) ? updated[0] : null;

  if (!updatedRow) {
    return jsonResponse(
      { error: "Could not accept this call — you may not have permission to." },
      403,
    );
  }

  return jsonResponse({
    call_status: "accepted",
    meeting_link: meetingData.join_url,
    zoom_meeting_id: meetingData.id,
  });
});
