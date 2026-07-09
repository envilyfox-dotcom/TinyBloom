import { serve } from "std/http/server";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type ChatMessage = {
  role?: string;
  text?: string;
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

function buildSystemPrompt(): string {
  return [
    "You are TinyBloom AI Assistant, a warm pregnancy education chatbot.",
    "Give general pregnancy information only.",
    "Do not diagnose, prescribe medication, or replace a doctor, midwife, clinic, hospital, or emergency services.",
    "Format every answer neatly in mobile-friendly Markdown.",
    "Use this format:",
    "### Quick answer",
    "Give a short 1 to 2 sentence answer.",
    "",
    "### What to know",
    "Use 3 to 5 short bullet points only.",
    "",
    "### When to seek help",
    "Mention urgent warning signs clearly when relevant.",
    "",
    "Keep answers concise, supportive, practical, and easy to read on a phone.",
    "Avoid long paragraphs.",
    "Avoid tables.",
    "For danger signs such as heavy bleeding, severe abdominal pain, severe headache, blurred vision, chest pain, fainting, fever with worsening symptoms, leaking fluid, or reduced/no baby movement, clearly advise urgent medical help.",
    "End with this exact disclaimer unless already included: TinyBloom provides general information only and does not replace advice from your doctor, midwife or hospital.",
  ].join("\n");
}

function buildUserContext(body: Record<string, unknown>): string {
  const question = safeString(body.question);
  const section = safeString(body.section);
  const sectionType = safeString(body.sectionType);

  const pregnancyProfile =
    body.pregnancyProfile && typeof body.pregnancyProfile === "object"
      ? (body.pregnancyProfile as Record<string, unknown>)
      : null;

  const contextLines: string[] = [];

  if (section) contextLines.push(`Selected section: ${section}`);
  if (sectionType) contextLines.push(`Section type: ${sectionType}`);

  if (pregnancyProfile) {
    const currentWeek =
      pregnancyProfile.current_week ?? pregnancyProfile.pregnancy_week;
    const dueDate = pregnancyProfile.due_date;
    const status = pregnancyProfile.pregnancy_status;
    const interests = pregnancyProfile.areas_of_interest;
    const needs = pregnancyProfile.consultation_needs;

    if (currentWeek) contextLines.push(`Pregnancy week: ${currentWeek}`);
    if (dueDate) contextLines.push(`Due date: ${dueDate}`);
    if (status) contextLines.push(`Pregnancy status: ${status}`);
    if (interests) contextLines.push(`Areas of interest: ${interests}`);
    if (needs) contextLines.push(`Consultation needs: ${needs}`);
  }

  const context =
    contextLines.length > 0
      ? `\n\nUser context:\n${contextLines.join("\n")}`
      : "";

  return `${question}${context}`;
}

function buildGeminiContents(body: Record<string, unknown>) {
  const rawMessages = Array.isArray(body.messages)
    ? (body.messages as ChatMessage[])
    : [];

  const contents = [];

  for (const message of rawMessages.slice(-8)) {
    const text = safeString(message.text);
    if (!text) continue;

    contents.push({
      role: message.role === "user" ? "user" : "model",
      parts: [{ text }],
    });
  }

  contents.push({
    role: "user",
    parts: [{ text: buildUserContext(body) }],
  });

  return contents;
}

function extractGeminiText(data: Record<string, unknown>): string {
  const candidates = data.candidates;

  if (!Array.isArray(candidates) || candidates.length === 0) return "";

  const firstCandidate = candidates[0];

  if (!firstCandidate || typeof firstCandidate !== "object") return "";

  const content = (firstCandidate as Record<string, unknown>).content;

  if (!content || typeof content !== "object") return "";

  const parts = (content as Record<string, unknown>).parts;

  if (!Array.isArray(parts)) return "";

  const textParts: string[] = [];

  for (const part of parts) {
    if (!part || typeof part !== "object") continue;

    const text = safeString((part as Record<string, unknown>).text);
    if (text) textParts.push(text);
  }

  return textParts.join("\n").trim();
}

function localSafetyFallback(question: string): string {
  const lower = question.toLowerCase();

  if (
    lower.includes("bleed") ||
    lower.includes("bleeding") ||
    lower.includes("severe headache") ||
    lower.includes("blurred vision") ||
    lower.includes("reduced movement") ||
    lower.includes("no movement") ||
    lower.includes("chest pain") ||
    lower.includes("faint") ||
    lower.includes("severe pain") ||
    lower.includes("leaking fluid")
  ) {
    return "This may need urgent medical attention. Please contact your doctor, clinic, maternity unit, hospital, or local emergency services immediately if symptoms are severe, worsening, or you feel unsafe.\n\nTinyBloom provides general information only and does not replace advice from your doctor, midwife or hospital.";
  }

  return "I could not connect to the AI service just now. TinyBloom can provide general pregnancy information, but for personal symptoms or urgent concerns, please contact your doctor, clinic, hospital, or emergency services.\n\nTinyBloom provides general information only and does not replace advice from your doctor, midwife or hospital.";
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let body: Record<string, unknown>;

  try {
    body = await req.json();
  } catch (_error) {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const question = safeString(body.question);

  if (!question) {
    return jsonResponse({ error: "Missing question" }, 400);
  }

  const apiKey = safeString(Deno.env.get("GEMINI_API_KEY"));
  const model = safeString(Deno.env.get("GEMINI_MODEL")) || "gemini-2.0-flash";

  if (!apiKey) {
    return jsonResponse({
      reply: localSafetyFallback(question),
      error: "GEMINI_API_KEY is not configured",
      status: 500,
    });
  }

  try {
    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify({
          systemInstruction: {
            parts: [{ text: buildSystemPrompt() }],
          },
          contents: buildGeminiContents(body),
          generationConfig: {
            temperature: 0.3,
            maxOutputTokens: 450,
          },
        }),
      }
    );

    const responseText = await geminiResponse.text();

    if (!geminiResponse.ok) {
      console.error("Gemini API error:", {
        status: geminiResponse.status,
        statusText: geminiResponse.statusText,
        details: responseText,
      });

      return jsonResponse({
        reply: localSafetyFallback(question),
        error: "Gemini API request failed",
        status: geminiResponse.status,
        statusText: geminiResponse.statusText,
        model,
        details: responseText,
      });
    }

    const data = JSON.parse(responseText) as Record<string, unknown>;
    const reply = extractGeminiText(data);

    if (!reply) {
      return jsonResponse({
        reply: localSafetyFallback(question),
        error: "Gemini returned an empty reply",
        status: 500,
        model,
        details: data,
      });
    }

    return jsonResponse({
      reply,
      model,
    });
  } catch (error) {
    console.error("tinybloom-chat Gemini error:", error);

    return jsonResponse({
      reply: localSafetyFallback(question),
      error: "TinyBloom Gemini chat function failed",
      status: 500,
      details: error instanceof Error ? error.message : String(error),
    });
  }
});