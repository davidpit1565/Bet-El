# Play "Data safety" form - suggested answers (verify against privacy.html before submitting; you are the one attesting)
What the Android build actually does (from the code, as of 2.0.3):
- Reading progress, favourites, names, dedications, yahrzeits, settings: **only on the device** (localStorage) - not sent anywhere, so NOT "collected" in Play's terms.
- Location (GPS, for zmanim): **used on the device only**, never sent to our servers.
- Firebase (web SDK, project bet-el-e6812): Analytics (usage events), an anonymous visit counter and "online now" presence in Firestore/Realtime DB. Since the 2.0.3 fix, native shells (Android) are no longer treated as localhost dev, so these DO run on Android.
- Feedback form: **name, email, subject and message** the user types (plus the device user-agent and language) are sent to Firestore `feedback` (optional, user-initiated).
- Camera (tefillin mirror): on-device only, never uploaded.
- iOS-only daily version check against Apple is not part of the Android build; web push tokens are not created on Android (verified: the Firebase Messaging plugin is excluded).
- Push notifications: NOT used on Android (the Firebase Messaging plugin is excluded from the Android build).
- Everything goes over HTTPS.

Suggested form answers:
- Does your app collect or share any of the required user data types? **Yes** (because of Analytics + feedback).
- Data types: **Personal info > Name and Email address** (feedback form: collected, not shared, optional; purpose: App functionality / Developer communications) and **Messages > Other in-app messages**. **App activity > App interactions** (Analytics) - collected, not shared, optional? No (Analytics is always on) - purpose: Analytics. **Device or other IDs** (Firebase installation ID used by Analytics) - collected, not shared, purpose: Analytics. **Messages/Other user-generated content** only if you count the feedback text: collected, not shared, optional, purpose: App functionality.
- Is all of the user data encrypted in transit? **Yes**.
- Can users request that data be deleted? **Yes** - by e-mailing the support address (state that in privacy.html as well).
If you want the simplest accurate form, ask me to switch Analytics off on Android; then the only item left is the optional feedback text.


## Camera (Tefillin mirror, versionCode 6+)
The CAMERA permission is used only for a live on-device preview in the Tefillin mirror guide. Frames are analysed locally by MediaPipe and are never recorded, stored or sent anywhere - nothing to declare under "Data collected".
