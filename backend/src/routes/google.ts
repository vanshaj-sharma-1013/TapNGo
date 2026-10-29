import type { FastifyInstance } from "fastify";
import { config } from "../config.js";
import { db } from "../firebase.js";

// Google sign-in for the game, done in the player's browser:
//   1. The game opens GET /auth/google?session=<random id> in the browser.
//   2. That page shows Google's sign-in button and POSTs the resulting Google ID token
//      to /auth/google/complete.
//   3. The game polls GET /auth/google/result?session=<id>, receives the token once,
//      and exchanges it with Firebase itself.
// The session id is a 128-bit random value made by the game, so only that game can collect it.

const SESSION_TTL_MS = 10 * 60 * 1000;
const SESSION_PATTERN = /^[0-9a-f]{32}$/;

const PAGE = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Tap N Go sign-in</title>
<style>
  body { margin: 0; min-height: 100vh; display: flex; flex-direction: column; align-items: center;
         justify-content: center; gap: 20px; padding: 24px; box-sizing: border-box; text-align: center;
         background: #05080a; color: #e8f9ff; font-family: system-ui, sans-serif; }
  h1 { margin: 0; color: #00e5ff; text-shadow: 0 0 12px #ff2e93; letter-spacing: 2px; }
</style>
</head>
<body>
<h1>TAP N GO</h1>
<p id="msg">Sign in with Google to play.</p>
<div id="btn"></div>
<script src="https://accounts.google.com/gsi/client" async defer></script>
<script>
  const session = "__SESSION__";
  const msg = document.getElementById("msg");
  const btn = document.getElementById("btn");
  function onCredential(response) {
    msg.textContent = "Finishing sign-in...";
    fetch("/auth/google/complete", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ session: session, idToken: response.credential }),
    }).then(function (res) {
      if (!res.ok) throw new Error("rejected");
      btn.remove();
      msg.textContent = "Signed in! You can go back to the game now.";
    }).catch(function () {
      msg.textContent = "Something went wrong. Close this page and try again from the game.";
    });
  }
  window.addEventListener("load", function () {
    google.accounts.id.initialize({ client_id: "__CLIENT_ID__", callback: onCredential });
    google.accounts.id.renderButton(btn, { theme: "filled_blue", size: "large", text: "continue_with" });
  });
</script>
</body>
</html>`;

export async function googleRoutes(app: FastifyInstance): Promise<void> {
  app.get("/auth/google", async (request, reply) => {
    const { session } = request.query as { session?: string };
    if (!config.googleClientId) {
      return reply.code(503).type("text/plain").send("Google sign-in is not set up on this server yet.");
    }
    if (!session || !SESSION_PATTERN.test(session)) {
      return reply.code(400).type("text/plain").send("Open this page from the game.");
    }
    return reply
      .type("text/html")
      .send(PAGE.replace("__SESSION__", session).replace("__CLIENT_ID__", config.googleClientId));
  });

  app.post(
    "/auth/google/complete",
    { config: { rateLimit: { max: 20, timeWindow: "1 minute" } } },
    async (request, reply) => {
      const body = request.body as { session?: unknown; idToken?: unknown } | null;
      const session = body?.session;
      const idToken = body?.idToken;
      if (
        typeof session !== "string" || !SESSION_PATTERN.test(session) ||
        typeof idToken !== "string" || idToken.length > 4096 || idToken.split(".").length !== 3
      ) {
        return reply.code(400).send({ error: "INVALID_REQUEST" });
      }
      await db.collection("googleSessions").doc(session).set({ idToken, expiresAt: Date.now() + SESSION_TTL_MS });
      return { ok: true };
    },
  );

  // The game polls this every couple of seconds, hence the roomier limit.
  app.get(
    "/auth/google/result",
    { config: { rateLimit: { max: 120, timeWindow: "1 minute" } } },
    async (request, reply) => {
      if (!config.googleClientId) {
        return reply.code(503).send({ error: "GOOGLE_NOT_CONFIGURED" });
      }
      const { session } = request.query as { session?: string };
      if (!session || !SESSION_PATTERN.test(session)) {
        return reply.code(400).send({ error: "INVALID_REQUEST" });
      }
      const ref = db.collection("googleSessions").doc(session);
      const snap = await ref.get();
      if (!snap.exists) {
        return { pending: true };
      }
      // One-time: whoever collects the token removes it.
      await ref.delete();
      const data = snap.data() as { idToken: string; expiresAt: number };
      if (Date.now() > data.expiresAt) {
        return { pending: true };
      }
      return { idToken: data.idToken };
    },
  );
}
