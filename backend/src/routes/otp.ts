import { createHmac, randomInt, timingSafeEqual } from "node:crypto";
import type { FastifyInstance } from "fastify";
import { requireUser } from "../auth.js";
import { config } from "../config.js";
import { auth, db } from "../firebase.js";
import { sendCodeEmail } from "../mailer.js";

const CODE_TTL_MS = 10 * 60 * 1000;
const RESEND_COOLDOWN_MS = 60 * 1000;
const MAX_ATTEMPTS = 5;

interface OtpDoc {
  hash: string;
  expiresAt: number;
  sentAt: number;
  attempts: number;
}

function hashCode(uid: string, code: string): string {
  return createHmac("sha256", config.otpPepper).update(`${uid}:${code}`).digest("hex");
}

export async function otpRoutes(app: FastifyInstance): Promise<void> {
  app.post(
    "/otp/send",
    {
      preHandler: requireUser,
      config: { rateLimit: { max: 10, timeWindow: "10 minutes" } },
    },
    async (request, reply) => {
      const user = await auth.getUser(request.uid);
      if (user.emailVerified) {
        return { ok: true, alreadyVerified: true };
      }
      if (!user.email) {
        return reply.code(400).send({ error: "NO_EMAIL" });
      }

      const ref = db.collection("otp").doc(request.uid);
      const existing = await ref.get();
      const now = Date.now();
      if (existing.exists && now - (existing.data() as OtpDoc).sentAt < RESEND_COOLDOWN_MS) {
        return reply.code(429).send({ error: "RESEND_TOO_SOON" });
      }

      const code = randomInt(0, 1_000_000).toString().padStart(6, "0");
      const doc: OtpDoc = { hash: hashCode(request.uid, code), expiresAt: now + CODE_TTL_MS, sentAt: now, attempts: 0 };
      await ref.set(doc);
      try {
        await sendCodeEmail(user.email, code);
      } catch (err) {
        request.log.error(err, "sending the code email failed");
        await ref.delete();
        return reply.code(502).send({ error: "EMAIL_FAILED" });
      }
      return { ok: true };
    },
  );

  app.post("/otp/verify", { preHandler: requireUser }, async (request, reply) => {
    const body = request.body as { code?: unknown } | null;
    const code = typeof body?.code === "string" ? body.code : "";
    if (!/^\d{6}$/.test(code)) {
      return reply.code(400).send({ error: "INVALID_CODE" });
    }

    const ref = db.collection("otp").doc(request.uid);
    const expected = hashCode(request.uid, code);
    // A transaction so parallel guesses can't dodge the attempt counter.
    const outcome = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        return "CODE_EXPIRED";
      }
      const data = snap.data() as OtpDoc;
      if (Date.now() > data.expiresAt) {
        tx.delete(ref);
        return "CODE_EXPIRED";
      }
      if (data.attempts >= MAX_ATTEMPTS) {
        return "TOO_MANY_CODE_ATTEMPTS";
      }
      const given = Buffer.from(expected);
      const stored = Buffer.from(data.hash);
      if (given.length !== stored.length || !timingSafeEqual(given, stored)) {
        tx.update(ref, { attempts: data.attempts + 1 });
        return "INVALID_CODE";
      }
      tx.delete(ref);
      return "OK";
    });

    if (outcome !== "OK") {
      return reply.code(outcome === "TOO_MANY_CODE_ATTEMPTS" ? 429 : 400).send({ error: outcome });
    }
    await auth.updateUser(request.uid, { emailVerified: true });
    return { ok: true };
  });
}
