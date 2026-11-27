# PassItOn (Project P07) — Implementation Changelog

**Branch:** `main` (final release hardening, verification, push, and Spark deployment)  
**Target Firebase Project:** `pass-it-on-2f422` (Spark Plan)  
**Architecture Enforced:** `Widget -> Provider -> Repository -> Firebase` + pure domain logic (`lib/domain/marketplace_logic.dart`)

---

## 1. User-Approved Design Decisions Implemented

1. **Images — Option B (No Firebase Cloud Storage / No New Firestore Base64)**
   - Removed `lib/utils/storage_uploader.dart` and `lib/utils/photo_picker*.dart`.
   - Enforced optional external `https://` image URL validation (`AppFormatters.isValidHttpsImageUrl` / `validateOptionalHttpsImageUrl`) across `AuthScreen`, `ProfileScreen`, `SellScreen` (`CreateListingSheet`), `AuthProvider`, and `SellProvider`.
   - When an avatar URL is blank or fails to load, `UserAvatar` falls back cleanly to crisp initials; when a listing has no external image URL, `SmartListingImage` + shared `ListingCategoryArtwork` renders deterministic category gradients and icons (stopped injecting external Unsplash stock URLs on empty listing forms).
   - Preserved backwards-compatible read rendering in `SmartListingImage` for any pre-existing legacy URLs/data without creating new base64 writes.

2. **Bottom Navigation — Four Primary Tabs + Top-Bar Messages**
   - Updated `RootScreen` so mobile `NavigationBar` renders strictly 4 destinations: **Explore**, **Sell**, **Offers**, and **Profile**.
   - Kept **Messages** 1-tap accessible via a top-bar icon button with live unread indicator badge (`ChatProvider.unreadThreadsCount`) across both mobile and desktop layouts.

3. **Admin Console & Optional Fee Checkout (Free / Spark Compatible)**
   - Preserved `AdminScreen` and `PaymentCheckoutSheet` with safe defaults (`feesEnabled: false`, `gatewayMode: 'spark_sandbox'`), removing paid-gateway UI branding (`SERVER SECURED` / `SSLCommerz` labels updated to `SANDBOX MODE (FREE)` / `Sandbox Payment Recorded`) and requiring explicit admin toggle before fee prompts appear.

4. **Cloud Functions Removal from Normal Operations**
   - Stopped calling unavailable `/api/*` endpoints from runtime providers; Spark-plan Firestore transactions, repositories, and hardened `firestore.rules` serve as the primary backend. `functions/` and `lib/services/backend_api.dart` remain untouched on disk for reference only.

---

## 2. Layered Architecture & Code Changes

### Domain Layer
- **`lib/domain/marketplace_logic.dart`** (New):
  - `buildTitleKeywords` & `tokenizeQuery` for lowercase title keyword generation and single-field `arrayContains` Firestore querying.
  - `filterAndSortListings` (category, condition, location, price range, negotiable, availability, favourites, query text; sorts: `Newest`, `Price low`, `Price high`).
  - `isOfferTimestampExpired` (48-hour expiry window check).
  - `OfferStateMachine`: `validateOfferSubmission` (blocks own listing, `<= 0` amounts, deleted/sold/reserved listings, duplicate active accepted/completed offers, and **blocks reactivation of expired offers** while warning when `amount > listing.price`) and `validateTransition` (enforces exact source states, buyer vs seller actor rules, handover PIN matching, counter-offer asymmetry, and listing lock transitions).
  - `MarketplaceLogic.mapError` for consistent user-facing error normalization (offline/unavailable, permission-denied, validation errors).

### Models & Utilities
- **`lib/utils/formatters.dart`**: Added `unknownUserName = 'Unknown user'`, `isValidHttpsImageUrl`, `validateOptionalHttpsImageUrl`.
- **`lib/models.dart`**:
  - Added optional `hostel` field on `PublicUserProfile`.
  - Standardized missing member name fallbacks to `'Unknown user'` (`PublicUserProfile`, `Listing`, `MarketOffer`, `ChatMessage`, `ListingComment`, `SellerReview`).
  - Added `keywords`, `isDeleted`, and `isNoLongerAvailable` getters on `Listing`.
  - Added `isExpiredAt([DateTime?])`, `effectiveStatus`, `isActiveOffer`, and `isTerminal` on `MarketOffer`.
  - Added `lastMessageSenderId`, `lastReadAtBy`, and `isUnreadFor(uid)` on `ChatThread`.

### Repositories (`lib/repositories/`)
- **`member_lookup.dart`**: Shared `resolveMemberProfile` helper querying `public_profiles` -> `users` fallback cleanly.
- **`listing_repository.dart`**: Added `ListingRepository` interface & `FirestoreListingRepository` (`pageSize = 30`, `watchInitialPage` `limit(30)`, `fetchPage` `startAfterDocument()`, `searchByKeywords`, `resolveFavoriteListings` retaining sold and deleted/missing favourited stubs via cached metadata, comments & seller listing CRUD).
- **`offer_repository.dart`**: Added `OfferRepository` & `FirestoreOfferRepository`:
  - Transactional `submitOffer` verifying live listing existence/availability at commit time.
  - Transactional `transitionOffer`: reads offer, listing, stats docs (on completion), and up to `maxCompetingOffersInTransaction = 480` competing pending/countered offers BEFORE any write; validates via `OfferStateMachine`; reserves listing & declines competing offers atomically inside `runTransaction` (with chunked overflow cleanup fallback if >480 competing offers ever existed, while preserving the single-winner listing reservation atomically); updates `soldCount` / `boughtCount` + `lastCompletedOfferId` on completion.
  - Transactional `releaseReservedListingWithOffers` & `completeReservedListingBySeller` keeping linked accepted offers and verified trade counters consistent.
  - `markExpiredIfDue` aligned with Firestore server `request.time`.
- **`rating_repository.dart`**: Added `RatingRepository` & `FirestoreRatingRepository` validating `!ratingSnap.exists`, `listing.status == 'sold'`, `offer.status == 'completed'`, and buyer/seller identity inside `runTransaction` before incrementing `ratingSum`/`ratingCount` with `lastRatingId`.
- **`auth_repository.dart` & `community_repository.dart`**: Encapsulated FirebaseAuth/Firestore operations for accounts (`hostel`, `department`, phone OTP, password reset, account deletion), real-time chat read tracking (`markThreadRead`), reports, and admin moderation.

### Providers (`lib/providers/`)
Split the monolithic `app_providers.dart` into modular feature providers (while keeping `lib/providers/app_providers.dart` as a barrel export so imports remain compatible):
- **`theme_and_directory_provider.dart`**: `ThemeProvider` & `ProfileDirectoryProvider` (streams `public_profiles` rather than listing private `/users`, exposes `ratingSummaryFor(uid)`).
- **`auth_provider.dart`**: `AuthProvider` (`initializing`, `uid`, `displayName`, `currentAccount`, `isCurrentUserAdmin`, `isCurrentUserBanned`, optional `hostel`/`department`, strict HTTPS `photoUrl`).
- **`listing_provider.dart`**: `ListingProvider` implementing true cursor pagination (`limit(30)` + `startAfterDocument()`), duplicate-free tail merging, accurate `hasMore` last-page tracking, keyword search (including items beyond initial 30), `searchError` surfacing, optimistic `toggleFavorite` with rollback & error reporting, and `favoriteListings` preservation for sold/deleted items.
- **`sell_provider.dart`**: `SellProvider` fixing logout `loading = false` leak, computing `pendingOfferCountFor(listingId)`, validating HTTPS-only listing images, and wiring `reserveListing`, `releaseReservedListing`, and `markSold`.
- **`offer_provider.dart` & `rating_provider.dart`**: Delegating cleanly to `OfferRepository` and `RatingRepository`, triggering auto-expiry sweeps, and preventing rating tampering.
- **`community_providers.dart`**: `ReportProvider`, `ChatProvider` (`unreadThreadsCount`, `markThreadRead`), and `AdminProvider`.

### Screens & Widgets (`lib/main.dart`, `lib/screens/`, `lib/widgets/`)
Removed direct `FirebaseAuth.instance` and `FirebaseFirestore.instance` usage from all UI screens and widgets:
- **`main.dart`**: Routes using `AuthProvider` (`initializing`, `isSignedIn`, `guestMode`, `isCurrentUserBanned`, `isCurrentUserAdmin`).
- **`root_screen.dart`**: 4 bottom tabs + top-bar `Messages` & `Notifications`, responsive mobile AppBar flex layout preventing narrow-screen overflow.
- **`auth_screen.dart` & `profile_screen.dart`**: Separate optional `Department` and `Hostel / Hall` fields, optional external HTTPS avatar URL with live circular preview and initials fallback, and full profile editing via `AuthProvider`.
- **`browse_screen.dart`**: Search clear button + `searchError` banner, category label on `_ListingCard`, shared `ListingCategoryArtwork`, inline seller rating in `ListingDetailSheet`, distinct **Make Offer** + **Buy at Asking Price** actions on negotiable items, `> askingPrice` confirmation dialog, and seller-only inline **Edit / Reserve / Release / Mark Sold / Delete** actions with `busy` guards.
- **`sell_screen.dart`**: Option B HTTPS URL photo gallery + live category artwork preview, pending offer count badges on `_MyListingCard`, `Reserve` menu action, and `busy` guards.
- **`offers_screen.dart`**: Enforces seller vs buyer turn asymmetry, adds buyer **Decline Counter** (`'declineCounter'`) distinction alongside **Withdraw**, displays 48h expiry state cleanly as terminal.
- **`favourites_screen.dart`**: Keeps sold & removed/deleted favourited items visible with explicit `"Sold · No longer available"` / `"No longer available"` badges and working removal rollback feedback.
- **`chat_screen.dart`, `admin_screen.dart`, `seller_profile_sheet.dart`, `smart_image.dart`, `payment_checkout_sheet.dart`**: Migrated auth/profile lookups to providers, added `markThreadRead` and unread thread indicators, displayed optional `hostel`, and shared category fallback artwork.

### Security Rules & Emulator Suite
- **`firestore.rules`**:
  - Locked `/users/{uid}` reads to `isOwner(uid) || isAdmin()`.
  - Blocked direct client edits to `role`, `isAdmin`, `isBanned`, `verifiedStudent`, `soldCount`, `boughtCount`, `ratingSum`, `ratingCount`, `lastCompletedOfferId`, and `lastRatingId` unless accompanied by same-transaction proof (`existsAfter`/`getAfter` verifying a newly created rating or seller-completed offer + `statsCounted == false`), and locked `public_profiles/{uid}` stats to mirror verified `users/{uid}` values.
  - Required listing existence (`status == 'available'`) on offer creation/reopen, deterministic `${listingId}_${buyerId}` offer IDs, `sellerId` exclusivity for `counter` and pending `accept`, buyer exclusivity for `acceptCounter`/`declineCounter`/`withdraw`, server-time `request.time` 48h expiry checks, terminal expiry protection, and `get`/`getAfter` checks for buyer `acceptCounter` reservations & competing declines.
  - Locked `/ratings/{listingId}` creation to verified buyers of completed offers on `'sold'` listings (1-5 integer stars).
  - Scoped `/payments/{paymentId}` writes to `gatewayMode == 'spark_sandbox'` and owner/seller refund transitions.
- **`emulator_tests/package.json` & `emulator_tests/firestore_rules_test.mjs`**: Added `@firebase/rules-unit-testing` test suite covering PII isolation, stat/role tamper rejection, banned/anon denials, offer actor/expiry/atomic-accept rules, and completed-sale/duplicate-rating enforcement.


---

## 3. Final Release Hardening (`main`)

1. **Firestore Rules Security, Expression Budget & Production Parity (`firestore.rules`, `firestore.rules.production`):**
   - Refactored `/listings/{listingId}` and `/offers/{offerId}` update rules with `rules_version = '2'` `let`-scoped dispatch helpers (`actorState`, `canUpdateListing`, `canUpdateOffer`), keeping runtime CEL evaluation strictly below Firestore's 1,000-expression cap on both allowed and denied paths.
   - Restricted seller listing updates explicitly to allowed fields (`sellerName`/`sellerPhotoUrl` sync, detail edits when `available`/`reserved`, and transition-linked status changes) preventing tampering with `sellerId`, `createdAt`, `feePaid`, `feeTransactionId`, or forged `statsCounted`/`reservedFor`.
   - Linked reservation release (`reserved -> available`), seller handover completion (`reserved -> sold`), buyer counter-acceptance, and buyer meetup cancellation (`withdrawn`) via `get()` / `getAfter()` offer-state consistency checks.
   - Synced `firestore.rules.production` identically with `firestore.rules` (active Spark-plan production ruleset).
2. **Offer State Machine, Alternating Counter-Offers & Exact 48h Expiry (`lib/models.dart`, `lib/domain/marketplace_logic.dart`, `lib/screens/offers_screen.dart`):**
   - Fixed `MarketOffer.isExpiredAt` to compare exact `Duration(hours: 48)` instead of truncated integer hours (`inHours >= 48`).
   - Enforced alternating counter-offer turns (`lastUpdatedBy` check in both `MarketplaceLogic.validateTransition`, `OffersScreen` button visibility, and `firestore.rules`) so sellers cannot counter their own counter-offer (`"Counter"` label instead of `"Re-Counter"`).
   - Blocked buyers from resetting `countered` offers back to `pending` via `validateOfferSubmission` / `firestore.rules`, and omitted `createdAt` when updating an already `pending` offer so the 48h expiry clock cannot be reset.
   - Blocked `decline`, `withdraw`, and `counter` actions on expired (`>= 48h`) pending/countered offers across Dart logic, repositories, and `firestore.rules`, while permitting terminal `'expired'` cleanup.
3. **Concurrent Offers, Bounded Cleanup, Reservation Release & PII-Safe Stats (`lib/repositories/offer_repository.dart`, `lib/repositories/rating_repository.dart`, `lib/providers/sell_provider.dart`):**
   - Lowered in-transaction competing-offer decline limit to `maxCompetingOffersInTransaction = 450` (reserving headroom inside Firestore's 500-op transaction limit) and ran bounded chunked cleanup (`maxOverflowCleanupBatches = 30`, `overflowCleanupBatchSize = 300`) unconditionally after reserve/accept to catch both >450 overflow bids and late-arriving concurrent bids (throwing explicit `OfferValidationException` if the bounded cleanup budget is exhausted).
   - Hardened `releaseReservedListingWithOffers` and `completeReservedListingBySeller` into full transactions resolving deterministic `{listingId}_{buyerId}` offer IDs cleanly before writing.
   - Switched handover stat updates (`soldCount`/`boughtCount`) and rating stat updates (`ratingSum`/`ratingCount`) to `FieldValue.increment` in `OfferRepository` and `RatingRepository`, eliminating cross-user reads on private `/users/{uid}` documents while maintaining atomic verification in `firestore.rules`.
   - Restricted `SellProvider.pendingOfferCountFor` to `'available'` listings.
4. **Expanded Automated Verification (`test/marketplace_providers_test.dart`, `emulator_tests/firestore_rules_test.mjs`):**
   - Installed portable Eclipse Temurin OpenJDK 21 LTS (`21.0.13.1+2`) locally for Firebase Emulator execution.
   - Added unit/provider tests for counter-turn locks, buyer `countered -> pending` reset blocking, expired action blocking, buyer accepted-reservation withdrawal, late-arriving concurrent bids, and >450 competing offer bounded cleanup.
   - Added Firestore Emulator rules tests for seller protected listing fields & reservation release, counter-offer turns & post-reserve stale cleanup, verified handover completion & PII read isolation, and >48h / premature expiry rules.
