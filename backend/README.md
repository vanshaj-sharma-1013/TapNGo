# Tap N Go backend

Small Node.js (TypeScript, Fastify) API that the game talks to. It keeps the secrets the game must not hold.

| Route | Needs login | What it does |
|---|---|---|
| `POST /otp/send` | yes | Emails a 6-digit code (10 min expiry, 60 s resend wait) |
| `POST /otp/verify` | yes | Checks the code (5 tries per code), marks the email verified |
| `POST /runs/start` | verified | Starts an endless run, returns a signed run token |
| `POST /runs/finish` | verified | Rejects impossible scores, saves a new personal best to the leaderboard |
| `GET /auth/google` | no | Browser page with Google's sign-in button (opened by the game) |
| `POST /auth/google/complete` | no | That page hands over the Google token |
| `GET /auth/google/result` | no | The game collects the token once, then trades it to Firebase |
| `GET /health` | no | Uptime check |

## Google sign-in setup

1. Firebase console > Authentication > Sign-in method > **Google** > Enable, pick a support email, Save.
2. Open Google again there and expand **Web SDK configuration**. Copy the **Web client ID** into `GOOGLE_CLIENT_ID` in `.env` (and in Cloud Run when deployed).
3. Google Cloud console (same project) > APIs & Services > Credentials > open the **Web client (auto created by Google Service)**. Under **Authorized JavaScript origins** add `http://localhost`, `http://localhost:8080`, and later your Cloud Run `https://...run.app` URL. Changes can take a few minutes.
4. APIs & Services > OAuth consent screen: before launch, set the publishing status to **In production**. While it says "Testing", only listed test users can sign in.
5. Optional: add a Firestore TTL policy on `googleSessions.expiresAt` to auto-clean abandoned sign-in attempts.

"Login" means an `Authorization: Bearer <Firebase ID token>` header. The leaderboard is read by the game straight from Firestore; only this server writes to it.

## Run locally

1. Firebase console > Project settings > Service accounts > **Generate new private key**. Save it here as `serviceAccount.json` (git-ignored).
2. `copy .env.example .env` and fill it in (comments inside explain each value).
3. `npm install`, then `npm run dev`. Check http://localhost:8080/health.
4. Run the game from the Godot editor. `BACKEND_URL` in `cloud.gd` already points at localhost.

## Deploy to Google Cloud Run (free tier)

1. Enable billing on the Firebase project (Blaze). Cloud Run's free tier covers roughly 2M requests a month, so cost stays at zero at small scale. Set a **budget alert** in Cloud Billing.
2. Install the `gcloud` CLI and run `gcloud auth login`, then `gcloud config set project tapngo-4bed6`.
3. From this folder:
   ```
   gcloud run deploy tapngo-backend --source . --region europe-west1 --allow-unauthenticated --max-instances 3 --set-env-vars FIREBASE_PROJECT_ID=tapngo-4bed6,EMAIL_USER=you@gmail.com
   ```
   Put `OTP_PEPPER`, `RUN_SECRET` and `EMAIL_PASS` in Secret Manager and attach them with `--set-secrets` rather than `--set-env-vars`.
4. Copy the service URL it prints into `BACKEND_URL` in `cloud.gd`. It must be `https`.
5. Publish `firestore.rules` from the project root in the Firebase console.

`--allow-unauthenticated` is intended: the game calls the API without a Google login, and every route except `/health` checks the player's Firebase token itself.

## Email

Nodemailer sends through Gmail using `EMAIL_USER` and `EMAIL_PASS` (a Gmail app password). Gmail allows about 500 emails a day and codes sometimes land in spam. To change provider before launch, edit `createTransport` in `src/mailer.ts`.
