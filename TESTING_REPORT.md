# PassItOn (Project P07) — Testing Report

**Date:** 2026-11-27  
**Branch:** `p07-compliance` (local only; not pushed/deployed)  
**Environment Observed:**
- Windows 10/11 (`windows-x64`)
- Flutter `3.47.9` (channel stable), Dart `3.13.7`
- Firebase CLI `15.37.0`
- Node.js `v24.11.1`
- Java JDK (`java -version`): **Not installed / not found on `PATH`**

---

## 1. Automated Verification Summary

| Check | Status | Details |
|---|---|---|
| `npm --prefix emulator_tests install` | PASSED | Installed 111 npm packages (`@firebase/rules-unit-testing@^3.0.4`, `firebase@^10.14.1`) in `repo/emulator_tests/`. |
| `flutter pub get` | PASSED | Resolved all Flutter/Dart dependencies with zero conflicts. |
| `flutter analyze` | PASSED | `No issues found! (ran in 25.3s)` across all `lib/` and `test/` Dart files. |
| `flutter test` | **PASSED (37 / 37)** | All 37 unit, domain, provider, and widget tests passed (`+37: All tests passed!`). Zero skipped tests. |
| `flutter build web` | PASSED | `Compiling lib\main.dart for the Web... 71.7s`, `Wasm dry run succeeded.`, `Built build\web`. |
| **Firebase Firestore Emulator Rules Suite** | **NOT RUN (Blocked by missing Java JDK)** | `java` is missing from `PATH`. Test suite written in `emulator_tests/firestore_rules_test.mjs`; awaits OpenJDK 17 or 21 installation before running. |
| **Live Headless/Browser End-to-End Flow Verification** | **PARTIAL (Manual verification needed)** | Chrome DevTools MCP could not attach to the active Chrome session (`DevToolsActivePort` missing without remote debugging enabled). Widget UI/overflow coverage ran via `flutter test` on simulated `390x844` mobile viewports; live end-to-end Firebase flows should be walked through locally using the instructions below. |

---

## 2. Test Suite Breakdown (`37` Passing Tests in `flutter test`)

### `test/models_and_logic_test.dart`
- `Listing` model status getters (`isAvailable`, `isReserved`, `isSold`)
- `MarketOffer` status helpers & 48h `isExpired` detection (`pending`/`countered` vs terminal/accepted states)
- `ThemeProvider` light/dark toggle behavior
- `Listing` & `MarketOffer` platform fee payment fields and multi-photo gallery serialization
- Student `.edu`/`.ac` verification helpers & `PlatformMetrics` calculations
- Option B external `https://` image URL validator (accepts HTTPS/empty; rejects `http://`, `ftp://`, and `data:image` base64)
- `BackendApi` reference client HTTP 404 endpoint-unavailable handling
- Authentic Italian font families (`EBGaramond`, `BodoniModa`, `Italiana`)
- Phone number normalization, validation, masking, and Gmail recovery validation
- `PublicUserProfile` completion percent, rating calculation, and `ProfileDirectoryProvider` caching
- `ListingComment` & standardized `'Unknown user'` missing-seller fallback

### `test/marketplace_providers_test.dart` (In-Memory Fake Repositories Driving Real Providers)
- Cursor-based pagination with `limit(30)` + `startAfter` cursor without duplicate items, plus accurate `hasMore` false behavior on the last partial page
- Server-backed keyword search (`keywords` array) finding items beyond the initial 30-item page, plus clean `searchError` surfacing on simulated search failures
- Multi-filter (`category`, `condition`, `price` range, `onlyNegotiable`), sorting (`Price high`), `activeFilterCount`, and `resetAllFilters()` consistency
- Optimistic `toggleFavorite` persistence across sold/deleted items (`No longer available` deleted stub via cached metadata) AND clean rollback + error surfacing on Firestore failure
- `SellProvider` validation (`title`/`description`/`price` bounds, rejecting non-HTTPS listing URLs), empty URL omitting fallback photo string, and resetting `loading = false` safely on sign-out
- **Atomic Offer Acceptance & Concurrency:** seller accepting Offer A atomically reserves listing, generates Handover PIN, and declines competing Offer B in the same commit; concurrent accept attempt on competing Offer B fails cleanly
- **Offer Counter Asymmetry:** seller `counter` updates amount/turn; buyer cannot counter back and seller cannot call `acceptCounter`; buyer `declineCounter` leaves listing `'available'`
- **48-Hour Expiry:** offers older than 48h reject `accept`/`counter`, transition cleanly to `'expired'`, and cannot be reactivated via `validateOfferSubmission`
- **Handover Completion & Verified Ratings:** wrong Handover PIN rejected; premature rating before sale completion rejected; correct PIN completes offer & marks listing `'sold'`; buyer rates seller once (updating `ratingSum`/`ratingCount`), and duplicate rating is rejected
- **Reservation Release:** `SellProvider.releaseReservedListing` restores listing `'available'` and declines linked accepted offer
- **Chat Unread Badge State:** `ChatProvider.unreadThreadsCount` excludes already-read threads and clears immediately on `markThreadRead`

### `test/widget_test.dart`
- `SmartListingImage` base64 legacy decode & `ListingCategoryArtwork.fallback` icon/gradient rendering
- `LegalPoliciesDialog` open/close and section verification
- `AnimatedUI` (`ShimmeringBadge`, `RadarPulseBeacon`) rendering
- `UserAvatar` initials & `'Unknown user'` fallback + verified badge check
- `BrowseScreen` rendered at `390x844` mobile viewport across **Loading** (`ListingGridSkeleton`), **Error** (`Unable to load listings`), **Empty Filtered** (`Clear filters`), and **Populated Card** states with zero `RenderFlex` overflow
- `FavouritesScreen` rendering sold saved listings with `"Sold · No longer available"` badge
- `RootScreen` verifying strictly 4 bottom navigation tabs (`Explore`, `Sell`, `Offers`, `Profile`), top-bar `Messages` button, and guest prompt on `390x844` with zero overflow
- `ListingDetailSheet` verifying guest prompt, missing seller `'Unknown user'` fallback, and mobile scrollable layout with zero overflow

---

## 3. Emulator Security Rules Suite (`emulator_tests/firestore_rules_test.mjs`)

Prepared (not yet executed locally pending OpenJDK installation) to test against the Firebase Firestore Emulator:
1. Unauthenticated / cross-user `users/{uid}` PII read blocking vs owner access & public `public_profiles` reads
2. Blocking self-promotion (`role: 'admin'`, `isAdmin: true`, `verifiedStudent: true`) and direct stat tampering (`soldCount`, `ratingSum`, `ratingCount`)
3. Blocking unauthenticated and `isBanned: true` writes on listings and offers
4. Enforcing seller-only offer acceptance/counter, blocking direct buyer listing reservation, rejecting expired (>48h) offer acceptance, and permitting expired-status marking
5. Verifying atomic offer acceptance reserving listing & declining competing offers in one transaction
6. Enforcing verified completed-sale rating prerequisites, bystander rejection, atomic rating stats update, and duplicate-rating rejection

---

## 4. OpenJDK 17 / 21 Installation & Verification Instructions

To run the Firestore Emulator security rules tests locally:

1. Download and install the free **Eclipse Temurin OpenJDK 21 LTS (x64 `.msi`)** installer for Windows from [https://adoptium.net/](https://adoptium.net/) (check **"Add to PATH"** and **"Set JAVA_HOME variable"** during setup).
2. Open a **new** PowerShell terminal and verify Java is active:
   ```powershell
   java -version
   ```
3. Run the Firebase Firestore Emulator security rules test suite inside `c:\Mobile _app_with_copilot\repo`:
   ```powershell
   cd "c:\Mobile _app_with_copilot\repo"
   npx firebase emulators:exec --only firestore "npm --prefix emulator_tests test"
   ```

---

## 5. Instructions to Run the App Locally

Run locally from `c:\Mobile _app_with_copilot\repo` (use `--web-port=8080` or let Flutter launch Chrome):

```powershell
cd "c:\Mobile _app_with_copilot\repo"
flutter pub get
flutter run -d chrome
```
Or for Windows desktop:
```powershell
cd "c:\Mobile _app_with_copilot\repo"
flutter run -d windows
```

> [!NOTE]
> Running locally connects to Firebase Auth & Cloud Firestore on project `pass-it-on-2f422`. Notice the live production `firestore.rules` on Firebase have **NOT** been deployed yet — therefore, local emulator rules tests verify the hardened rules, whereas testing writes that depend on updated rule conditions against live Firebase will match currently deployed rules until your separate deployment approval.
