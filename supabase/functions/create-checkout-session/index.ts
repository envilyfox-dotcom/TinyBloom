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
    "authorization, x-client-info, apikey, content-type",
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

function safeString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const stripeSecretKey = safeString(Deno.env.get("STRIPE_SECRET_KEY"));
  const monthlyPriceId = safeString(Deno.env.get("STRIPE_MONTHLY_PRICE_ID"));
  const yearlyPriceId = safeString(Deno.env.get("STRIPE_YEARLY_PRICE_ID"));

  if (!stripeSecretKey || !monthlyPriceId || !yearlyPriceId) {
    return jsonResponse(
      {
        error: "Stripe secrets are not configured.",
        missing: {
          STRIPE_SECRET_KEY: !stripeSecretKey,
          STRIPE_MONTHLY_PRICE_ID: !monthlyPriceId,
          STRIPE_YEARLY_PRICE_ID: !yearlyPriceId,
        },
      },
      500,
    );
  }

  if (!stripeSecretKey.startsWith("sk_test_")) {
    return jsonResponse(
      {
        error: "Invalid Stripe secret key.",
        details:
          "For sandbox testing, STRIPE_SECRET_KEY must start with sk_test_. Do not use pk_test_.",
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

  const plan = safeString(body.plan);
  const userId = safeString(body.user_id) || "demo_user";
  const email = safeString(body.email);

  const priceId =
    plan === "premium_yearly"
      ? yearlyPriceId
      : plan === "premium_monthly"
        ? monthlyPriceId
        : "";

  if (!priceId) {
    return jsonResponse({ error: "Invalid subscription plan." }, 400);
  }

  const form = new URLSearchParams();

  form.append("mode", "subscription");

  if (email) {
    form.append("customer_email", email);
  }

  form.append("client_reference_id", userId);
  form.append("line_items[0][price]", priceId);
  form.append("line_items[0][quantity]", "1");

  form.append(
  "success_url",
  "tinybloom://payment-success?session_id={CHECKOUT_SESSION_ID}",
);
form.append("cancel_url", "tinybloom://payment-cancelled");

  form.append("metadata[user_id]", userId);
  form.append("metadata[plan]", plan);
  form.append("subscription_data[metadata][user_id]", userId);
  form.append("subscription_data[metadata][plan]", plan);

  try {
    const stripeResponse = await fetch(
      "https://api.stripe.com/v1/checkout/sessions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${stripeSecretKey}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: form,
      },
    );

    const data = await stripeResponse.json();

    if (!stripeResponse.ok) {
      return jsonResponse(
        {
          error: "Stripe Checkout session failed.",
          details: data,
        },
        400,
      );
    }

    return jsonResponse({
      url: data.url,
      id: data.id,
    });
  } catch (error) {
    return jsonResponse(
      {
        error: "Create checkout session failed.",
        details: error instanceof Error ? error.message : String(error),
      },
      500,
    );
  }
});