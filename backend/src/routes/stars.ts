import type { FastifyInstance } from "fastify";
import { Timestamp } from "firebase-admin/firestore";
import { requireUser } from "../auth.js";
import { auth, db } from "../firebase.js";
import { cleanUsername, isOffensive } from "../names.js";

const WORLDS = 4;
const LEVELS_PER_WORLD = 50;

// Total stars from a map like {"0:3": 2}. Returns null if anything in it is impossible.
function sumStars(stars: unknown): number | null {
  if (typeof stars !== "object" || stars === null || Array.isArray(stars)) {
    return null;
  }
  let total = 0;
  for (const [key, value] of Object.entries(stars)) {
    const match = /^(\d+):(\d+)$/.exec(key);
    if (!match || Number(match[1]) >= WORLDS || Number(match[2]) < 1 || Number(match[2]) > LEVELS_PER_WORLD) {
      return null;
    }
    if (typeof value !== "number" || !Number.isInteger(value) || value < 1 || value > 3) {
      return null;
    }
    total += value;
  }
  return total;
}

// The level board: one document per player in "starboard", written only here.
export async function starRoutes(app: FastifyInstance): Promise<void> {
  app.post(
    "/stars/sync",
    { preHandler: requireUser, config: { rateLimit: { max: 30, timeWindow: "1 minute" } } },
    async (request, reply) => {
      if (!request.emailVerified && !request.isGuest) {
        return reply.code(403).send({ error: "NOT_VERIFIED" });
      }
      const body = request.body as { stars?: unknown } | null;
      const total = sumStars(body?.stars);
      if (total === null) {
        return reply.code(400).send({ error: "INVALID_STARS" });
      }
      if (total === 0) {
        return { ok: true, total };
      }

      const [user, profile] = await Promise.all([
        auth.getUser(request.uid),
        db.collection("profiles").doc(request.uid).get(),
      ]);
      const cleaned = cleanUsername(user.displayName);
      const name = cleaned !== null && !isOffensive(cleaned) ? cleaned : "Player";
      const savedFullName: string = profile.data()?.fullName ?? "";
      const fullName = isOffensive(savedFullName) ? "" : savedFullName;
      await db.collection("starboard").doc(request.uid).set({ name, fullName, score: total, updatedAt: Timestamp.now() });
      return { ok: true, total };
    },
  );
}
