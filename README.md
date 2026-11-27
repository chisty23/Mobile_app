# PassItOn (Project P07)

Peer-to-peer campus marketplace built with Flutter and Firebase Spark (`pass-it-on-2f422`).

## Architecture & Core Features

- **Spark-Compatible Backend (`Widget -> Provider -> Repository -> Firebase` + `lib/domain/marketplace_logic.dart`):** Runs directly on Firebase Authentication and Cloud Firestore (Spark plan) with hardened `firestore.rules` and compound indexes (`firestore.indexes.json`). Cloud Functions (`functions/`) are retained in the repository for reference only and are not required at runtime or deployed.
- **Navigation:** 4 primary bottom tabs (**Explore**, **Sell**, **Offers**, **Profile**) with 1-tap top-bar access to **Messages** (unread badge tracked via `lastReadAtBy`) and **Notifications**.
- **Accounts & Privacy:** Firebase Phone/Password authentication with optional Hostel/Hall, Department, and student `.edu`/`.ac` verification. Private account fields live in `/users/{uid}` (strictly owner/admin readable), while public seller cards read `/public_profiles/{uid}`.
- **Images (Device Upload + HTTPS URL Fallback — Zero Cloud Storage):** Listing and avatar photos support **real device uploads** (picked via browser file dialog on Web or native `passiton/media_picker` channel on Android/iOS, compressed on-device to compact `<= 250 KB` JPEG Data URIs safely within Firestore's 1 MiB document budget) as well as optional external `https://` URLs, with initials (`UserAvatar`) and deterministic category gradient/icon artwork (`SmartListingImage` / `ListingCategoryArtwork`) fallbacks.
- **Offers, Expiry & Atomic Acceptance:**
  - Deterministic offer IDs (`{listingId}_{buyerId}`), strict actor/state validation in `MarketplaceLogic` and `firestore.rules`.
  - Alternating counter-offer turns (`lastUpdatedBy`), blocked buyer resets from `countered` back to `pending`, and exact 48-hour expiry (`Duration(hours: 48)` client-side and `request.time >= createdAt + 48h` in `firestore.rules`) blocking actions once expired.
  - Atomic acceptance (`OfferRepository.transitionOffer`): declines up to 450 competing pending/countered offers in the reservation transaction, plus bounded batch cleanup (up to 30 x 300 docs) for overflow or late-arriving offers; reservation release (`releaseReservedListingWithOffers`) and handover completion (`completeReservedListingBySeller` / `OfferAction.complete`) update listing, offer, and counters via `FieldValue.increment` without exposing cross-user `/users` PII.
- **Ratings, Admin & Fees:** Verified buyers of completed (`sold`) listings can submit one 1–5 star review (`ratings/{listingId}`). Admin moderation (`AdminScreen`) and optional sandbox-only fee checkout (`feesEnabled: false`, `gatewayMode: 'spark_sandbox'`) are preserved cleanly without paid APIs.

## Collections Covered by `firestore.rules`

- `users/{userId}` (and `favorites/{listingId}`)
- `public_profiles/{userId}`
- `phone_directory/{phoneKey}`
- `listings/{listingId}` (and `comments/{commentId}`)
- `offers/{offerId}`
- `chats/{threadId}` (and `messages/{msgId}`)
- `ratings/{listingId}`
- `reports/{reportId}`
- `platform_settings/{settingId}`
- `payments/{paymentId}`

## Local Setup & Verification

1. **Install dependencies:**
   ```powershell
   flutter pub get
   npm --prefix emulator_tests install
   ```
2. **Analyze & run Flutter unit/widget tests:**
   ```powershell
   flutter analyze
   flutter test
   ```
3. **Run Firestore Security Rules Emulator tests (requires OpenJDK 17 or 21 on `PATH`):**
   ```powershell
   java -version
   firebase emulators:exec --only firestore --project pass-it-on-p07-rules-test "npm --prefix emulator_tests test"
   ```
4. **Run locally / build web:**
   ```powershell
   flutter run -d chrome
   flutter build web --release --pwa-strategy=none
   ```
5. **Deploy to Firebase Spark (Hosting + Firestore rules/indexes only):**
   ```powershell
   firebase deploy --only firestore,hosting --project pass-it-on-2f422
   ```
