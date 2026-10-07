const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

// Set once with: firebase functions:secrets:set RESEND_API_KEY
// (get the key from https://resend.com after verifying a sending domain -
// see functions/README.md for the full one-time setup).
const RESEND_API_KEY = defineSecret("RESEND_API_KEY");

const SUPPORT_EMAIL = "info@bet-el.be";
const MAX_FIELD_LENGTH = 500;

/**
 * Silent feedback-form relay: the app's feedback form (openFeedbackForm()
 * in index.html / NativeFeedbackFormView.swift) posts {name, email,
 * message} here instead of opening the device's mail app - this sends
 * the email directly via Resend's API so "Send" in the app is a single
 * tap with nothing else to open or confirm. If this call fails for any
 * reason (network, missing key, Resend outage), the app falls back to
 * its original mailto: behavior - see sendFeedbackForm() in index.html.
 */
exports.sendFeedback = onRequest(
  { secrets: [RESEND_API_KEY], cors: true, region: "us-central1" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ ok: false, error: "method_not_allowed" });
      return;
    }

    const { name, email, message } = req.body || {};
    const subjectRaw = typeof (req.body || {}).subject === "string" ? req.body.subject.trim() : "";
    if (
      typeof name !== "string" || !name.trim() ||
      typeof email !== "string" || !email.trim() ||
      typeof message !== "string" || !message.trim()
    ) {
      res.status(400).json({ ok: false, error: "missing_fields" });
      return;
    }
    if (name.length > MAX_FIELD_LENGTH || email.length > MAX_FIELD_LENGTH || message.length > MAX_FIELD_LENGTH) {
      res.status(400).json({ ok: false, error: "field_too_long" });
      return;
    }

    const escapeHtml = (s) =>
      s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

    try {
      const resendResponse = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${RESEND_API_KEY.value()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          // Resend requires the "from" address's domain to be verified in
          // the Resend dashboard - replace once a domain (e.g.
          // feedback@bet-el.be) is verified there. Until then this
          // sandbox address only works for sending to the Resend
          // account's own verified email, not real users.
          from: "Bet-El App <onboarding@resend.dev>",
          to: [SUPPORT_EMAIL],
          reply_to: email,
          subject: (subjectRaw ? subjectRaw.slice(0, 150) : "משוב מהאפליקציה — תמיד"),
          text: `שם: ${name}\nאימייל: ${email}\nנושא: ${subjectRaw}\n\n${message}`,
          html: `<p><b>שם:</b> ${escapeHtml(name)}</p><p><b>אימייל:</b> ${escapeHtml(email)}</p><p><b>נושא:</b> ${escapeHtml(subjectRaw)}</p><p>${escapeHtml(message).replace(/\n/g, "<br>")}</p>`,
        }),
      });

      if (!resendResponse.ok) {
        const body = await resendResponse.text();
        logger.error("Resend API error", { status: resendResponse.status, body });
        res.status(502).json({ ok: false, error: "send_failed" });
        return;
      }

      res.status(200).json({ ok: true });
    } catch (err) {
      logger.error("sendFeedback failed", err);
      res.status(500).json({ ok: false, error: "internal" });
    }
  }
);
