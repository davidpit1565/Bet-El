/* Dedicated service worker for Firebase Cloud Messaging (Web Push).
   Separate from sw.js (the offline-cache service worker) - FCM's web SDK
   expects its own worker (by default named exactly this) to receive
   background push events and show the notification while the app isn't
   open/focused. Uses the compat build via importScripts since service
   workers don't support ES module imports the same way the main app's
   <script type="module"> does. */
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyC-_4GaF_IMR_Xy5d6LEFAT_1lvygCcfRQ",
  authDomain: "bet-el-e6812.firebaseapp.com",
  projectId: "bet-el-e6812",
  storageBucket: "bet-el-e6812.firebasestorage.app",
  messagingSenderId: "307340594758",
  appId: "1:307340594758:web:893ce10350a975e0624447",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const n = payload.notification || {};
  self.registration.showNotification(n.title || 'תָּמִיד', {
    body: n.body || '',
    icon: './icon-192.png',
    badge: './icon-192.png',
  });
});
