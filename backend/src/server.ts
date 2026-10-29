import Fastify from "fastify";
import rateLimit from "@fastify/rate-limit";
import { config } from "./config.js";
import { googleRoutes } from "./routes/google.js";
import { otpRoutes } from "./routes/otp.js";
import { runRoutes } from "./routes/runs.js";

async function main(): Promise<void> {
  // trustProxy: Cloud Run sits behind a proxy, so rate limits need the real client IP.
  const app = Fastify({ logger: true, trustProxy: true });
  app.decorateRequest("uid", "");
  app.decorateRequest("emailVerified", false);
  app.decorateRequest("isGuest", false);

  await app.register(rateLimit, {
    max: 60,
    timeWindow: "1 minute",
    errorResponseBuilder: () => ({ statusCode: 429, error: "RATE_LIMITED" }),
  });

  app.get("/health", async () => ({ ok: true }));
  await app.register(googleRoutes);
  await app.register(otpRoutes);
  await app.register(runRoutes);

  await app.listen({ port: config.port, host: "0.0.0.0" });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
