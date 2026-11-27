# PassItOn (Project P07) — Testing Report

**Date:** 2026-11-27  
**Branch:** `main`  
**Firebase Project:** `pass-it-on-2f422` (Spark Plan)  
**Environment Verified:**
- Windows 10/11 (`windows-x64`)
- Flutter `3.47.9` (channel stable), Dart `3.13.7`
- Firebase CLI `15.37.0`
- Node.js `v24.11.1`
- Eclipse Temurin OpenJDK `21.0.13.1+2` LTS (`C:\Users\USER\AppData\Local\Programs\temurin-jdk-21\jdk-21.0.13.1+2`)

---

## 1. Automated Verification Summary (Executed After Final Edits)

| Check | Status | Details |
|---|---|---|
| `npm --prefix emulator_tests install` | **PASSED** | Installed `@firebase/rules-unit-testing@^3.0.4` & `firebase@^10.14.1` in `repo/emulator_tests/`. |
| `flutter analyze --no-pub` | **PASSED** | `No issues found! (ran in 11.3s)` across all `lib/` and `test/` Dart files. |
| `flutter test --no-pub` | **PASSED (`40 / 40`)** | All 40 unit, domain, provider, and widget tests passed (`+40: All tests passed!`, 0 failed, 0 skipped). |
| **Firebase Firestore Emulator Rules Suite** (`firebase emulators:exec --only firestore --project pass-it-on-p07-rules-test "npm --prefix emulator_tests test"`) | **PASSED (`9 / 9`)** | All 9 Firestore security rules test suites passed (`pass 9, fail 0` in `10.16s`) against OpenJDK 21 LTS with **zero** `maximum of 1000 expressions` runtime ceiling errors. |
| `flutter build web --release --pwa-strategy=none --no-pub` | **PASSED** | `Compiling lib\main.dart for the Web... 65.3s`, `Wasm dry run succeeded.`, `Built build\web`. |

---

## 2. Flutter Suite Breakdown (`40` Passing Tests in `flutter test`)

### `test/models_and_logic_test.dart`
- `Listing` model status getters (`isAvailable`, `isReserved`, `isSold`)
- `MarketOffer` status helpers & exact 48-hour expiry (`Duration(hours: 48)` check on `pending`/`countered` vs terminal/accepted states)
- `ThemeProvider` light/dark toggle behavior
- `Listing` & `MarketOffer` platform fee payment fields and multi-photo gallery serialization
- Student `.edu`/`.ac` verification helpers & `PlatformMetrics` calculations
- Option B external `https://` image URL validator and hybrid device Data URI validator (`isValidDataImageUri`, `isValidImageSource`, `validateOptionalImageSource`: accepts HTTPS and compact `<= 260,000` char compressed JPEG/PNG/WebP Data URIs; rejects `http://`, `ftp://`, `data:text/html`, and oversized base64 strings)
- `BackendApi` reference client HTTP 404 endpoint-unavailable handling
- Authentic font families (`EBGaramond`, `BodoniModa`, `Italiana`)
- Phone number normalization, validation, masking, and Gmail recovery validation
- `PublicUserProfile` completion percent, rating calculation, and `ProfileDirectoryProvider` caching
- `ListingComment` & standardized `'Unknown user'` missing-seller fallback

### `test/marketplace_providers_test.dart`
- Cursor-based pagination with `limit(30)` + `startAfter` cursor without duplicate items, plus accurate `hasMore` false behavior on the last partial page
- Server-backed keyword search (`keywords` array) finding items beyond the initial 30-item page, plus clean `searchError` surfacing on simulated search failures
- Multi-filter (`category`, `condition`, `price` range, `onlyNegotiable`), sorting (`Price high`), `activeFilterCount`, and `resetAllFilters()` consistency
- Optimistic `toggleFavorite` persistence across sold/deleted items (`No longer available` deleted stub via cached metadata) AND clean rollback + error surfacing on Firestore failure
- `SellProvider` validation (`title`/`description`/`price` bounds, accepting mixed compressed device Data URIs + `https://` URLs, rejecting non-HTTPS links and oversized device URIs above Firestore cap), empty URL omitting fallback photo string, and resetting `loading = false` safely on sign-out
- **Atomic Offer Acceptance & Concurrency:** seller accepting Offer A atomically reserves listing, generates Handover PIN, and declines competing Offer B in the same commit; concurrent accept attempt on declined Offer B fails cleanly
- **Offer Counter Asymmetry & Turn Lock:** seller `counter` updates amount/turn (`lastUpdatedBy`); seller cannot double-counter their own previous counter-offer; buyer cannot counter back or reset a `countered` offer back to `pending`; seller cannot call `acceptCounter`; buyer `declineCounter` leaves listing `'available'`
- **48-Hour Expiry:** offers older than 48h reject `accept`, `counter`, `decline`, and `withdraw`, transition cleanly to `'expired'`, and cannot be reactivated via `validateOfferSubmission`
- **Handover Completion & Verified Ratings:** wrong Handover PIN rejected; premature rating before sale completion rejected; correct PIN completes offer & marks listing `'sold'`; buyer rates seller once, and duplicate rating is rejected
- **Reservation Release & Buyer Cancellation:** `SellProvider.releaseReservedListing` and buyer withdrawing an `accepted` offer both restore listing `'available'` and transition the accepted offer cleanly
- **Bounded Cleanup (`>450` Competing Offers + Late Arrivals):** in-memory simulation mirroring `FirestoreOfferRepository` (`maxCompetingOffersInTransaction = 450`, `overflowCleanupBatchSize = 300`, `maxOverflowCleanupBatches = 30`) verifies all 460 pre-existing competing offers plus an injected late-arrival concurrent offer transition to `'declined'` while preserving `'winner'`
- **Chat Unread Badge State:** `ChatProvider.unreadThreadsCount` excludes already-read threads and clears immediately on `markThreadRead`

### `test/widget_test.dart`
- `SmartListingImage` legacy decode & `ListingCategoryArtwork.fallback` icon/gradient rendering
- `LegalPoliciesDialog`, `AnimatedUI` skeletons/badges, and `UserAvatar` initials & `'Unknown user'` fallback
- `BrowseScreen`, `FavouritesScreen`, `RootScreen` (4 bottom tabs + top-bar `Messages`), `ListingDetailSheet` (`Make Offer` + `Buy at Asking Price`), and `CreateListingSheet` (`Choose Photo from Device` + `Or paste https:// image URL`, `Cover` thumbnail, responsive dropdowns) rendered at `390x844` mobile viewport with zero overflow

---

## 3. Emulator Security Rules Suite (`9` Passing Tests in `emulator_tests/firestore_rules_test.mjs`)

1. Unauthenticated / cross-user `/users/{uid}` PII read blocking vs owner access & public `public_profiles` reads
2. Blocking self-promotion (`role: 'admin'`, `isAdmin: true`, `verifiedStudent: true`) and direct stat tampering (`soldCount`, `ratingSum`, `ratingCount`)
3. Blocking unauthenticated and `isBanned: true` writes on listings and offers
4. Enforcing seller-only offer acceptance/counter, blocking direct buyer listing reservation, rejecting expired (>48h) offer acceptance, and permitting `'expired'` cleanup
5. Verifying atomic offer acceptance reserving listing & declining competing offers inside one transaction
6. Verifying completed-sale rating prerequisites (`sold` listing + `completed` offer), bystander rejection, atomic stats updates, and duplicate-rating rejection
7. Verifying seller listing update field restrictions (`sellerId`, `createdAt`, `feePaid`, `feeTransactionId`, `statsCounted`) and reservation release offer consistency
8. Verifying counter-offer alternating turns (`lastUpdatedBy`), buyer `countered -> pending` reset blocking, and post-reserve stale offer cleanup by winning buyer and seller
9. Verifying atomic handover completion (`offer: accepted -> completed`, `listing: reserved -> sold`, `statsCounted: true`, `FieldValue.increment` stats updates on `users` & `public_profiles` without cross-user `/users` PII reads) while blocking direct forgery, plus >48h expiry blocking (`decline`/`withdraw`/`counter`/buyer `pending` edits) vs premature expiry blocking

---

## 4. Known Scope Boundaries & Manual Verification Note

- **Bounded Competing Offer Guarantee:** Inside `runTransaction`, up to `450` competing `pending`/`countered` offers are declined atomically alongside reservation (respecting Firestore's hard 500-write transaction limit). Overflow (>450) and concurrent late-arrival bids are declined immediately after via bounded batches (up to `30 * 300 = 9,000` offers), raising an explicit `OfferValidationException` if exceeded. `460+1` cleanup was verified via `_FakeOfferRepository` unit tests mirroring the repository partitioning logic, while `firestore.rules` enforcement of post-reserve competing declines was verified in the Firestore Emulator.
- **Interactive Signed-In Flow:** Because end-to-end automated Phone OTP / Google OAuth sign-in against production Firebase Auth is not run in headless tests, post-deploy verification checks live Hosting availability and static bundle delivery, while interactive signed-in flows can be tested directly on `https://pass-it-on-2f422.web.app` (or locally via `flutter run -d chrome`).
