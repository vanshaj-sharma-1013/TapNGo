import { createHmac, timingSafeEqual } from "node:crypto";
import type { FastifyInstance } from "fastify";
import { Timestamp } from "firebase-admin/firestore";
import { requireUser } from "../auth.js";
import { config } from "../config.js";
import { auth, db } from "../firebase.js";
import { cleanUsername, isOffensive } from "../names.js";

// Score is metres climbed in endless mode. The player moves at 400 px/s (480 px/s in the
// Cyber Grid world, 1.2x) and endless.gd counts 50 px per metre, so nobody can
// legitimately beat 9.6 m/s.
const MAX_METRES_PER_SECOND = 9.6;
const TOLERANCE = 1.1;
const SLACK_METRES = 3;
const MAX_RUN_AGE_MS = 6 * 60 * 60 * 1000;
const MAX_SCORE = 1_000_000;

function sign(payload: string): string {
  return createHmac("sha256", config.runSecret).update(payload).digest("hex");
}

// A run token is "<uid>.<startMs>.<signature>", so starting a run needs no database write.
function makeRunToken(uid: string, startMs: number): string {
  const payload = `${uid}.${startMs}`;
  return `${payload}.${sign(payload)}`;
}

// Returns the start time (ms) if the token is genuine and belongs to `uid`.
function readRunToken(token: string, uid: string): number | null {
  const parts = token.split(".");
  if (parts.length !== 3 || parts[0] !== uid) {
    return null;
  }
  const expected = Buffer.from(sign(`${parts[0]}.${parts[1]}`));
  const given = Buffer.from(parts[2]);
  if (expected.length !== given.length || !timingSafeEqual(expected, given)) {
    return null;
  }
  const startMs = Number(parts[1]);
  return Number.isFinite(startMs) ? startMs : null;
}

export async function runRoutes(app: FastifyInstance): Promise<void> {
  app.post("/runs/start", { preHandler: requireUser }, async (request, reply) => {
    if (!request.emailVerified && !request.isGuest) {
      return reply.code(403).send({ error: "NOT_VERIFIED" });
    }
    return { run: makeRunToken(request.uid, Date.now()) };
  });

  app.post("/runs/finish", { preHandler: requireUser }, async (request, reply) => {
    if (!request.emailVerified && !request.isGuest) {
      return reply.code(403).send({ error: "NOT_VERIFIED" });
    }
    const body = request.body as { run?: unknown; score?: unknown } | null;
    const score = body?.score;
    if (typeof body?.run !== "string" || typeof score !== "number" || !Number.isInteger(score) || score < 1 || score > MAX_SCORE) {
      return reply.code(400).send({ error: "INVALID_RUN" });
    }

    const startMs = readRunToken(body.run, request.uid);
    const elapsedMs = startMs === null ? -1 : Date.now() - startMs;
    if (elapsedMs < 0 || elapsedMs > MAX_RUN_AGE_MS) {
      return reply.code(400).send({ error: "INVALID_RUN" });
    }
    // Revives and ad breaks only make a run longer, so this limit is never too strict.
    const limit = Math.floor((elapsedMs / 1000) * MAX_METRES_PER_SECOND * TOLERANCE) + SLACK_METRES;
    if (score > limit) {
      request.log.warn({ uid: request.uid, score, limit }, "rejected implausible score");
      return reply.code(422).send({ error: "SCORE_REJECTED" });
    }

    const [user, profile] = await Promise.all([
      auth.getUser(request.uid),
      db.collection("profiles").doc(request.uid).get(),
    ]);
    // Names are public here, so anything offensive (e.g. an email-based username) is hidden.
    const cleaned = cleanUsername(user.displayName);
    const name = cleaned !== null && !isOffensive(cleaned) ? cleaned : "Player";
    const savedFullName: string = profile.data()?.fullName ?? "";
    const fullName = isOffensive(savedFullName) ? "" : savedFullName;
    const ref = db.collection("leaderboard").doc(request.uid);
    const improved = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (snap.exists && (snap.data()?.score ?? 0) >= score) {
        return false;
      }
      tx.set(ref, { name, fullName, score, updatedAt: Timestamp.now() });
      return true;
    });
    return { ok: true, improved };
  });
}
