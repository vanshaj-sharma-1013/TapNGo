import nodemailer from "nodemailer";
import { config } from "./config.js";

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: { user: config.emailUser, pass: config.emailPass },
});

export async function sendCodeEmail(to: string, code: string): Promise<void> {
  await transporter.sendMail({
    from: `Tap N Go <${config.emailUser}>`,
    to,
    subject: `Your Tap N Go code: ${code}`,
    text: `Your Tap N Go verification code is ${code}.\n\nIt expires in 10 minutes. If you didn't sign up, ignore this email.`,
    html: `<p>Your Tap N Go verification code is:</p>
<p style="font-size:32px;font-weight:bold;letter-spacing:6px">${code}</p>
<p>It expires in 10 minutes. If you didn't sign up, ignore this email.</p>`,
  });
}
