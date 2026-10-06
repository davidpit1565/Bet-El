# Feedback-form email relay (Cloud Function)

This is what makes the app's "Send" button on the feedback form actually
deliver the email silently, with nothing to open or confirm, instead of
falling back to the device's mail app via `mailto:`.

Nothing here is deployed automatically — these are one-time steps to run
yourself, since deploying requires your own Firebase login and billing
plan.

## One-time setup

1. **Upgrade the Firebase project to the Blaze (pay-as-you-go) plan.**
   Cloud Functions that make outbound network calls (to Resend, in this
   case) require Blaze — the free Spark plan can't do this. Blaze still
   has a generous free tier; a low-volume feedback form like this one
   will cost close to nothing.
   https://console.firebase.google.com/project/bet-el-e6812/usage/details

2. **Create a free Resend account** at https://resend.com and verify a
   sending domain you control (e.g. `bet-el.be`) under
   Domains → Add Domain, following their DNS instructions. Until a domain
   is verified, Resend only lets you send to your own account's email —
   fine for testing the function once deployed, not for real users yet.

3. **Update the `from` address** in `functions/index.js` once your domain
   is verified — replace `onboarding@resend.dev` with something like
   `Bet-El App <feedback@bet-el.be>`.

4. **Create a Resend API key** (Resend dashboard → API Keys) and store it
   as a Firebase secret (never commit the key itself):
   ```
   firebase functions:secrets:set RESEND_API_KEY
   ```
   (paste the key when prompted).

5. **Install the Firebase CLI** if you don't have it yet, then log in:
   ```
   npm install -g firebase-tools
   firebase login
   ```

6. **Deploy the function** from the repo root:
   ```
   firebase deploy --only functions
   ```
   This reads `firebase.json`/`.firebaserc` (already in the repo root) and
   deploys the `sendFeedback` function from this `functions/` directory.
   The deployed URL will be:
   ```
   https://us-central1-bet-el-e6812.cloudfunctions.net/sendFeedback
   ```
   which is already hardcoded as `FEEDBACK_FN_URL` in `index.html` — no
   other change needed once deployed.

## Testing

Until the above is done, the feedback form still works exactly as before
(it falls back to `mailto:` automatically whenever the Cloud Function
call fails — offline, not yet deployed, wrong/missing key, etc.), so
there's no rush and no risk in deploying this whenever convenient.

After deploying, submit the feedback form in the app once and confirm the
email arrives at info@bet-el.be instead of opening the Mail app.
