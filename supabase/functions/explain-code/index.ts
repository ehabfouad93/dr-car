// Supabase Edge Function: explains Logan fault codes in Egyptian Arabic.
// The Claude API key lives here only (secret ANTHROPIC_API_KEY), never in the app.
//
// Deploy:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//   supabase functions deploy explain-code
import Anthropic from "npm:@anthropic-ai/sdk";

const client = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

// Fixed reply format the app renders (see lib/services/ai_service.dart).
const schema = {
  type: "object",
  properties: {
    meaning: { type: "string" },
    likely_causes: { type: "array", items: { type: "string" } },
    cheap_checks: { type: "array", items: { type: "string" } },
    urgency: { type: "string", enum: ["drive", "soon", "stop"] },
    tell_mechanic: { type: "string" },
    links_between_codes: { type: "array", items: { type: "string" } },
  },
  required: ["meaning", "likely_causes", "cheap_checks", "urgency", "tell_mechanic", "links_between_codes"],
  additionalProperties: false,
};

const SYSTEM = `You are a Renault Logan diagnostic assistant inside an Egyptian car app.
The car is ALWAYS: Renault Logan 2015 (Logan II / X52), K7M 1.6 8-valve petrol, manual JH3 gearbox.
Facts about this car you must use:
- Cable throttle + idle stepper motor on the throttle body (no electronic throttle, no VVT, no cam sensor).
- One wasted-spark coil pack (cylinders 1+4 and 2+3), MAP sensor (no MAF), crank/TDC sensor on the gearbox bell housing.
- ECU-controlled radiator fan through relays; the cluster has no coolant gauge, only a warning light.
- Common failures: dirty idle stepper/throttle body, cracked coil pack, crank sensor or its connector (hot no-start),
  coolant temp sensor/connector, weak water pump -> overheating, fan relay, speed sensor wiring, weak battery/alternator.
- Many cars in Egypt run CNG conversions, which shift fuel trims and cause lean/misfire codes.
- Low battery/charging voltage can cause false sensor codes: check voltage first.
Rules:
- Write every field in simple Egyptian Arabic (عامية مصرية), short sentences.
- Never say a cause is certain. Say "غالبًا" and give a cheap check that proves it.
- Likely causes: most likely first, specific to this car.
- urgency: "stop" if driving can damage the engine or is unsafe, "soon" for this week, "drive" if safe.
- Link codes to each other when one can cause another.
- Never suggest ECU remapping, odometer changes, or disabling airbag/ABS warnings.`;

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response("bad json", { status: 400 });
  }

  try {
    const response = await client.beta.messages.create({
      model: "claude-opus-5-5",
      max_tokens: 16000,
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      output_config: { effort: "medium", format: { type: "json_schema", schema } },
      system: SYSTEM,
      messages: [{
        role: "user",
        content: `Explain fault code ${String(body.focus_code)} for this car. Full scan data:\n` +
          JSON.stringify(
            {
              car: body.car,
              codes: body.codes,
              freeze_frame: body.freeze_frame,
              live_snapshot: body.live,
              owner_notes: body.user_notes,
            },
            null,
            1,
          ),
      }],
    });

    if (response.stop_reason === "refusal") {
      return new Response("refused", { status: 422 });
    }
    const text = response.content.find((b) => b.type === "text");
    if (!text || text.type !== "text") return new Response("empty", { status: 502 });
    return new Response(text.text, { headers: { "Content-Type": "application/json; charset=utf-8" } });
  } catch (e) {
    if (e instanceof Anthropic.RateLimitError) return new Response("busy", { status: 429 });
    if (e instanceof Anthropic.APIError) return new Response("ai error", { status: 502 });
    return new Response("server error", { status: 500 });
  }
});
