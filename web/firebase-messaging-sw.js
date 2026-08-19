/* Background FCM handler for the installed SotongWareControl PWA. */
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBd9l_VwFPMpavJAXEASghVd5ueJpQHSkw',
  appId: '1:417281978999:web:39ebce3135d7a646d0cc72',
  messagingSenderId: '417281978999',
  projectId: 'sotongware-control',
  authDomain: 'sotongware-control.firebaseapp.com',
  storageBucket: 'sotongware-control.firebasestorage.app'
});

firebase.messaging();
