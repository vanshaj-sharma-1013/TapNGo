import type { FastifyInstance } from "fastify";
import { requireUser } from "../auth.js";
import { auth, db } from "../firebase.js";
import { cleanFullName, cleanUsername, isOffensive } from "../names.js";

// The username lives in Firebase Auth (displayName). The optional full name has no home
// there, so it sits in profiles/{uid}, which clients can't touch (see firestore.rules).
export async function profileRoutes(app: FastifyInstance): Promise<void> {
  app.get("/profile", { preHandler: requireUser }, async (request) => {
    const user = await auth.getUser(request.uid);
    const profile = await db.collection("profiles").doc(request.uid).get();
    return { username: user.displayName ?? "", fullName: profile.data()?.fullName ?? "" };
  });

  app.post(
    "/profile",
    { preHandler: requireUser, config: { rateLimit: { max: 10, timeWindow: "1 minute" } } },
    async (request, reply) => {
      const body = request.body as { username?: unknown; fullName?: unknown } | null;
      const username = cleanUsername(body?.username);
      if (username === null) {
        return reply.code(400).send({ error: "INVALID_USERNAME" });
      }
      const fullName = cleanFullName(body?.fullName);
      if (fullName === null) {
        return reply.code(400).send({ error: "INVALID_FULL_NAME" });
      }

      if (isOffensive(username) || isOffensive(fullName)) {
        return reply.code(400).send({ error: "NAME_NOT_ALLOWED" });
      }

      await auth.updateUser(request.uid, { displayName: username });
      await db.collection("profiles").doc(request.uid).set({ fullName });
      // Keep an existing leaderboard entry in step. Players without a score have none yet.
      const entry = db.collection("leaderboard").doc(request.uid);
      if ((await entry.get()).exists) {
        await entry.update({ name: username, fullName });
      }
      const stars = db.collection("starboard").doc(request.uid);
      if ((await stars.get()).exists) {
        await stars.update({ name: username, fullName });
      }
      return { ok: true, username, fullName };
    },
  );
}
