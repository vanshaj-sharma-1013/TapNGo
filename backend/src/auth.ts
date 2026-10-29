import type { FastifyReply, FastifyRequest } from "fastify";
import { auth } from "./firebase.js";

declare module "fastify" {
  interface FastifyRequest {
    uid: string;
    emailVerified: boolean;
    isGuest: boolean;
  }
}

// preHandler: accepts "Authorization: Bearer <Firebase ID token>" and sets request.uid.
export async function requireUser(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const header = request.headers.authorization ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token) {
    return reply.code(401).send({ error: "UNAUTHENTICATED" });
  }
  try {
    const decoded = await auth.verifyIdToken(token);
    request.uid = decoded.uid;
    request.emailVerified = decoded.email_verified === true;
    request.isGuest = decoded.firebase.sign_in_provider === "anonymous";
  } catch {
    return reply.code(401).send({ error: "UNAUTHENTICATED" });
  }
}
