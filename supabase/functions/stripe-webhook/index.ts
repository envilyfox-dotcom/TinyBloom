declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
  serve(
    handler: (req: Request) => Response | Promise<Response>,
  ): void;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, stripe-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(
      { error: "Supabase service role credentials are missing." },
      500,
    );
  }

  let event: Record<string, any>;

  try {
    event = await req.json();
  } catch (_error) {
    return jsonResponse({ error: "Invalid webhook JSON." }, 400);
  }

  if (event.type !== "checkout.session.completed") {
    return jsonResponse({ received: true, ignored: event.type });
  }

  const session = event.data?.object;

  const userId = session?.metadata?.user_id;
  const plan = session?.metadata?.plan;

  if (!userId || !plan) {
    return jsonResponse(
      {
        error: "Missing user_id or plan in Stripe metadata.",
        metadata: session?.metadata ?? null,
      },
      400,
    );
  }

  const updateResponse = await fetch(
    `${supabaseUrl}/rest/v1/profiles?id=eq.${userId}`,
    {
      method: "PATCH",
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: JSON.stringify({
        subscription_plan: plan,
        role: "premium_user",
        updated_at: new Date().toISOString(),
      }),
    },
  );

  const updateText = await updateResponse.text();

  if (!updateResponse.ok) {
    return jsonResponse(
      {
        error: "Failed to update Supabase profile.",
        details: updateText,
      },
      500,
    );
  }

  return jsonResponse({
    received: true,
    user_id: userId,
    plan,
    updated: true,
  });
});