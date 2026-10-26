const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

admin.initializeApp();

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


/* ======================================================================
   Automatic push announcements (no Firebase Console campaign needed).
   Both functions send straight to the FCM tokens the apps store in the
   Firestore `pushTokens` collection (iOS + web), in each token's own
   language, and delete tokens FCM reports as dead.
   ====================================================================== */
const LANGS = ["he", "en", "fr", "ru", "ka"];
const langOf = (t) => {
  const l = String((t && t.lang) || "he").toLowerCase().slice(0, 2);
  return LANGS.includes(l) ? l : (l === "iw" ? "he" : "en");
};

/** Sends {he,en,fr,ru,ka}-> {title, body} texts to every stored token, grouped by language. */
async function broadcast(texts, data) {
  const db = admin.firestore();
  const snap = await db.collection("pushTokens").select("lang").get();
  const groups = {};
  snap.forEach((d) => {
    const lang = langOf(d.data());
    (groups[lang] = groups[lang] || []).push(d.id);
  });
  let sent = 0, failed = 0;
  const dead = [];
  for (const lang of Object.keys(groups)) {
    const text = texts[lang] || texts.en || texts.he;
    const tokens = groups[lang];
    for (let i = 0; i < tokens.length; i += 500) {
      const chunk = tokens.slice(i, i + 500);
      const res = await admin.messaging().sendEachForMulticast({
        tokens: chunk,
        notification: { title: text.title, body: text.body },
        data: data || {},
        apns: { headers: { "apns-priority": "10" }, payload: { aps: { sound: "default" } } },
        webpush: { headers: { TTL: "86400" } },
      });
      res.responses.forEach((r, idx) => {
        if (r.success) { sent++; return; }
        failed++;
        const code = r.error && r.error.code;
        const msg = (r.error && r.error.message) || "";
        if (code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token" ||
            (code === "messaging/invalid-argument" && /registration token/i.test(msg))) dead.push(chunk[idx]);
      });
    }
  }
  // circuit breaker: if NOTHING was delivered the cause is probably our payload/credentials, not dead tokens - delete nothing
  if (sent > 0) await Promise.all(dead.map((t) => db.collection("pushTokens").doc(t).delete().catch(() => {})));
  logger.info("broadcast done", { sent, failed, removedDead: sent > 0 ? dead.length : 0, tokens: snap.size });
  return { sent, failed };
}

const MILESTONE_TEXT = {
  he: (n) => ({ title: `ברוך השם — ${n} משתמשים!`, body: `ברוך השם עברנו את ה-${n} משתמשים! תודה שאתה חלק מהקהילה. 🙏` }),
  en: (n) => ({ title: `Thank G-d — ${n} Users!`, body: `Thank G-d, we’ve passed ${n} users! Thank you for being part of the community. 🙏` }),
  fr: (n) => ({ title: `Grâce à D.ieu — ${n} utilisateurs !`, body: `Grâce à D.ieu, nous avons dépassé ${n} utilisateurs ! Merci de faire partie de la communauté. 🙏` }),
  ru: (n) => ({ title: `Слава Богу — ${n} пользователей!`, body: `Слава Богу, мы превысили ${n} пользователей! Спасибо, что вы часть этой общины. 🙏` }),
  ka: (n) => ({ title: `მადლობა ღმერთს — ${n} მომხმარებელი!`, body: `მადლობა ღმერთს, გადავაბიჯეთ ${n} მომხმარებელს! გმადლობთ, რომ ჩვენი საზოგადოების ნაწილი ხართ. 🙏` }),
};

/**
 * Fires when the public user counter (stats/visits.count) crosses a multiple of 100 (300, 400, 500, ...), once per
 * milestone for everyone - tracked in stats/announced so retries / duplicate triggers never send it twice.
 */
const MILESTONES_ENABLED = false;   // user decision: no more "N users" announcements (the counter is hidden in the app)
exports.milestonePush = onDocumentUpdated({ document: "stats/visits", region: "us-central1", timeoutSeconds: 540, memory: "512MiB", maxInstances: 1 }, async (event) => {
  if (!MILESTONES_ENABLED) return;
  const before = (event.data.before.data() || {}).count || 0;
  const after = (event.data.after.data() || {}).count || 0;
  const tier = Math.floor(after / 100) * 100;
  if (tier < 300 || Math.floor(before / 100) * 100 >= tier) return;
  const ref = admin.firestore().doc("stats/announced");
  const first = await admin.firestore().runTransaction(async (tx) => {
    const d = (await tx.get(ref)).data() || {};
    const cur = d.milestone || 0;
    if (cur >= tier) return false;
    if (d.milestoneAt && Date.now() - d.milestoneAt < 24 * 3600 * 1000) return false;   // at most one milestone push per day (spam guard)
    tx.set(ref, { milestone: tier, milestoneAt: Date.now(), milestonePrev: cur }, { merge: true });
    return true;
  });
  if (!first) return;
  const n = tier.toLocaleString("en-US");
  const texts = {};
  LANGS.forEach((l) => { texts[l] = MILESTONE_TEXT[l](n); });
  try {
    const r = await broadcast(texts, { kind: "milestone", count: String(tier) });
    if (r.sent === 0 && r.failed > 0) throw new Error("nothing delivered");
  } catch (e) {
    // roll the marker back so a transient failure (APNs key, timeout) is retried by the next increment instead of lost
    await ref.set({ milestone: (await ref.get()).data().milestonePrev || 0, milestoneAt: 0 }, { merge: true });
    throw e;
  }
});

const BOOKLET_URL = "https://davidpit1565.github.io/Bet-El/data/booklet/current.json";
const BOOKLET_TEXT = {
  he: (t) => ({ title: "חוברת השבוע", body: `${t} — החוברת החדשה מחכה לך באפליקציה 📖` }),
  en: (t) => ({ title: "This week's booklet", body: `${t} — the new booklet is waiting in the app 📖` }),
  fr: (t) => ({ title: "Le livret de la semaine", body: `${t} — le nouveau livret vous attend dans l’application 📖` }),
  ru: (t) => ({ title: "Брошюра недели", body: `${t} — новая брошюра ждёт вас в приложении 📖` }),
  ka: (t) => ({ title: "კვირის ბროშურა", body: `${t} — ახალი ბროშურა აპლიკაციაში გელოდებათ 📖` }),
};

/**
 * Every Sunday 07:00 (Jerusalem) - right after netz, when the app starts showing the new weekly booklet - reads the live
 * data/booklet/current.json from GitHub Pages and announces it once (id remembered in stats/announced). If you publish the
 * booklet later in the week it is announced at the next run (the schedule also runs Sun-Fri at 07:00 and only sends when
 * the booklet id is new and its Shabbat is within the coming 7 days).
 */
exports.bookletPush = onSchedule({ schedule: "0 7 * * 0-5", timeZone: "Asia/Jerusalem", region: "us-central1", timeoutSeconds: 540, memory: "512MiB", maxInstances: 1 }, async () => {
  const res = await fetch(BOOKLET_URL + "?t=" + Date.now(), { headers: { "cache-control": "no-cache" }, signal: AbortSignal.timeout(10000) });
  if (!res.ok) { logger.info("no current booklet", { status: res.status }); return; }
  let list = await res.json();
  if (!Array.isArray(list)) list = [list];
  const now = Date.now();
  const cur = list.find((b) => {
    if (!b || !b.id || !b.shabbat) return false;
    const days = (Date.parse(b.shabbat + "T12:00:00Z") - now) / 86400000;
    return days >= -0.5 && days <= 7;
  });
  if (!cur) return;
  const ref = admin.firestore().doc("stats/announced");
  const first = await admin.firestore().runTransaction(async (tx) => {
    const d = (await tx.get(ref)).data() || {};
    if (d.booklet === cur.id) return false;
    tx.set(ref, { booklet: cur.id, bookletPrev: d.booklet || "" }, { merge: true });
    return true;
  });
  if (!first) return;
  const title = typeof cur.title === "string" ? { he: cur.title, en: cur.title } : (cur.title || {});
  const texts = {};
  LANGS.forEach((l) => { texts[l] = BOOKLET_TEXT[l](String(title[l] || title.en || title.he || "").slice(0, 100)); });
  try {
    const r = await broadcast(texts, { kind: "booklet", id: String(cur.id) });
    if (r.sent === 0 && r.failed > 0) throw new Error("nothing delivered");
  } catch (e) {
    await ref.set({ booklet: (await ref.get()).data().bookletPrev || "" }, { merge: true });   // retry at the next scheduled run
    throw e;
  }
});
