import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { config } from "./config.js";

// Locally this reads the key file in GOOGLE_APPLICATION_CREDENTIALS; on Cloud Run it uses
// the service account the service runs as.
initializeApp({
  credential: applicationDefault(),
  projectId: config.firebaseProjectId,
});

export const auth = getAuth();
export const db = getFirestore();
