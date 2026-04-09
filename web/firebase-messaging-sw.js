// Firebase Messaging Service Worker for web push notifications
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDZRIwJGLtdo4n2PDlMfjv4A3cRrCKw62k",
  authDomain: "gbo-updated.firebaseapp.com",
  projectId: "gbo-updated",
  storageBucket: "gbo-updated.firebasestorage.app",
  messagingSenderId: "295754050567",
  appId: "1:295754050567:web:630345ba20b01c8de20ea2",
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  const notificationTitle = payload.notification?.title || "RHBL Benachrichtigung";
  const notificationOptions = {
    body: payload.notification?.body || "",
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    data: payload.data,
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
