# PassItOn

PassItOn is Project P07: a second-hand campus marketplace built with Flutter, Firebase Authentication, Cloud Firestore, and Provider.

## Setup

1. Run `flutter pub get`.
2. The app is configured for Firebase project `pass-it-on-2f422`.
3. Enable Email/Password authentication in Firebase Console.
4. Create a Cloud Firestore database.
5. Deploy `firestore.rules` with `firebase deploy --only firestore:rules`.
6. Run `flutter run -d chrome` or `flutter run` on a device.

## Features

- Email/password registration and login
- Real-time marketplace listings and favourites
- Search, category filters, sorting, and listing details
- Listing creation and status management
- Made and received offer streams
- Pending, countered, accepted, declined, withdrawn, and expired offer states
- Transaction-based offer acceptance and listing reservation
- Seller ratings and user profile data
- Loading, empty, error, and offline-friendly states
- Double-tap saving and action busy states
- Glassmorphic premium Material UI

## Firestore Structure

- `users/{uid}`
- `users/{uid}/favorites/{listingId}`
- `listings/{listingId}`
- `offers/{offerId}`
- `ratings/{listingId}`

Timestamps for application writes use `FieldValue.serverTimestamp()`. Passwords are managed only by Firebase Authentication.
