function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing environment variable ${name}`);
  }
  return value;
}

export const config = {
  port: Number(process.env.PORT ?? 8080),
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID ?? "tapngo-4bed6",
  otpPepper: required("OTP_PEPPER"),
  runSecret: required("RUN_SECRET"),
  // Optional: without it the Google sign-in routes answer "not set up".
  googleClientId: process.env.GOOGLE_CLIENT_ID ?? "",
  emailUser: required("EMAIL_USER"),
  emailPass: required("EMAIL_PASS"),
};
