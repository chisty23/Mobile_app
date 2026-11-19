import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models.dart';

class AuthProvider extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  bool busy = false;
  String? error;

  User? get user => _auth.currentUser;

  Future<bool> login(String email, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      error = e.message ?? 'Login failed';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String department = '',
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());
      await _db.collection('users').doc(credential.user!.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'department': department.trim(),
        'soldCount': 0,
        'boughtCount': 0,
        'ratingSum': 0,
        'ratingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } on FirebaseAuthException catch (e) {
      error = e.message ?? 'Registration failed';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}

class ListingProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _listingSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _favoriteSub;
  List<Listing> listings = [];
  Set<String> favoriteIds = {};
  bool loading = true;
  String? error;
  String query = '';
  String category = 'All';
  String condition = 'All';
  String sort = 'Newest';
  int minPrice = 0;
  int maxPrice = 100000000;
  StreamSubscription<User?>? _authSub;

  ListingProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      favoriteIds = {};
      listings = [];
      loading = true;
      _startStreams();
    });
    _startStreams();
  }

  void _startStreams() {
    _listingSub?.cancel();
    _listingSub = _db
        .collection('listings')
        .where('status', whereIn: ['available', 'reserved'])
        .limit(30)
        .snapshots()
        .listen(
          (snapshot) {
            listings = snapshot.docs.map(Listing.fromSnapshot).toList();
            loading = false;
            error = null;
            notifyListeners();
          },
          onError: (e) {
            loading = false;
            error = 'Could not load listings';
            notifyListeners();
          },
        );

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _favoriteSub?.cancel();
      _favoriteSub = _db
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .snapshots()
          .listen((snapshot) {
            favoriteIds = snapshot.docs.map((d) => d.id).toSet();
            notifyListeners();
          });
    }
  }

  List<Listing> get filtered {
    var result = listings.where((listing) {
      final matchesQuery =
          query.isEmpty ||
          listing.title.toLowerCase().contains(query.toLowerCase());
      final matchesCategory = category == 'All' || listing.category == category;
      final matchesCondition =
          condition == 'All' || listing.condition == condition;
      final matchesPrice =
          listing.price >= minPrice && listing.price <= maxPrice;
      return matchesQuery &&
          matchesCategory &&
          matchesCondition &&
          matchesPrice;
    }).toList();
    if (sort == 'Price low') {
      result.sort((a, b) => a.price.compareTo(b.price));
    } else if (sort == 'Price high') {
      result.sort((a, b) => b.price.compareTo(a.price));
    } else {
      result.sort((a, b) {
        final ac = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bc = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bc.compareTo(ac);
      });
    }
    return result;
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  void setCategory(String value) {
    category = value;
    notifyListeners();
  }

  void setCondition(String value) {
    condition = value;
    notifyListeners();
  }

  void setSort(String value) {
    sort = value;
    notifyListeners();
  }

  Future<void> toggleFavorite(Listing listing) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(listing.id);
    if (favoriteIds.contains(listing.id)) {
      await ref.delete();
    } else {
      await ref.set({
        'listingTitle': listing.title,
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  void dispose() {
    _listingSub?.cancel();
    _favoriteSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}

class SellProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<Listing> myListings = [];
  bool loading = true;
  bool busy = false;
  String? error;
  StreamSubscription<User?>? _authSub;

  SellProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      myListings = [];
      loading = true;
      _sub?.cancel();
      _startStream();
    });
    _startStream();
  }

  void _startStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _sub = _db
        .collection('listings')
        .where('sellerId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) {
            myListings = snapshot.docs.map(Listing.fromSnapshot).toList();
            loading = false;
            notifyListeners();
          },
          onError: (_) {
            loading = false;
            error = 'Could not load your listings';
            notifyListeners();
          },
        );
  }

  Future<bool> createListing({
    required String title,
    required String description,
    required String category,
    required String condition,
    required int price,
    required bool negotiable,
    String imageUrl = '',
  }) async {
    if (title.trim().isEmpty || description.trim().isEmpty || price <= 0) {
      error = 'Enter a title, description, and a positive price';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final profile = await _db.collection('users').doc(user.uid).get();
      final name =
          (profile.data()?['name'] as String?) ??
          user.displayName ??
          'Unknown user';
      final keywords = title
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList();
      await _db.collection('listings').add({
        'title': title.trim(),
        'keywords': keywords,
        'description': description.trim(),
        'category': category,
        'condition': condition,
        'price': price,
        'negotiable': negotiable,
        'imageUrl': imageUrl.trim(),
        'sellerId': user.uid,
        'sellerName': name,
        'status': 'available',
        'reservedFor': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } on FirebaseException catch (e) {
      error = e.message ?? 'Could not create listing';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> updateStatus(
    Listing listing,
    String status, {
    String reservedFor = '',
  }) async {
    busy = true;
    notifyListeners();
    try {
      await _db.collection('listings').doc(listing.id).update({
        'status': status,
        'reservedFor': reservedFor,
      });
      return true;
    } on FirebaseException catch (e) {
      error = e.message ?? 'Could not update listing';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> deleteListing(Listing listing) async {
    await _db.collection('listings').doc(listing.id).delete();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}

class OfferProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _madeSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _receivedSub;
  List<MarketOffer> made = [];
  List<MarketOffer> received = [];
  bool busy = false;
  String? error;
  StreamSubscription<User?>? _authSub;

  OfferProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      made = [];
      received = [];
      _madeSub?.cancel();
      _receivedSub?.cancel();
      _startStreams();
    });
    _startStreams();
  }

  void _startStreams() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _madeSub = _db
        .collection('offers')
        .where('buyerId', isEqualTo: uid)
        .snapshots()
        .listen(
          (s) =>
              made = s.docs.map(MarketOffer.fromSnapshot).toList()
                ..sort(_offerSort),
        );
    _receivedSub = _db
        .collection('offers')
        .where('sellerId', isEqualTo: uid)
        .snapshots()
        .listen(
          (s) =>
              received = s.docs.map(MarketOffer.fromSnapshot).toList()
                ..sort(_offerSort),
        );
  }

  int _offerSort(MarketOffer a, MarketOffer b) {
    final am =
        a.updatedAt?.millisecondsSinceEpoch ??
        a.createdAt?.millisecondsSinceEpoch ??
        0;
    final bm =
        b.updatedAt?.millisecondsSinceEpoch ??
        b.createdAt?.millisecondsSinceEpoch ??
        0;
    return bm.compareTo(am);
  }

  Future<bool> makeOffer(Listing listing, int amount, String message) async {
    if (listing.sellerId == FirebaseAuth.instance.currentUser?.uid) {
      error = 'You cannot make an offer on your own listing';
      notifyListeners();
      return false;
    }
    if (amount <= 0) {
      error = 'Offer must be greater than zero';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final buyerName =
          FirebaseAuth.instance.currentUser?.displayName ?? 'Buyer';
      final offerRef = _db.collection('offers').doc('${listing.id}_$uid');

      await _db
          .runTransaction((transaction) async {
            final listingRef = _db.collection('listings').doc(listing.id);
            final listingSnap = await transaction.get(listingRef);
            if (!listingSnap.exists)
              throw Exception('This listing no longer exists');
            final live = listingSnap.data()!;
            if (live['status'] == 'sold') {
              throw Exception('This listing has already been sold');
            }
            if (live['status'] != 'available') {
              throw Exception('This listing is not available');
            }

            final offerSnap = await transaction.get(offerRef);
            final existing = offerSnap.data();
            if (existing != null) {
              final status = existing['status'];
              if (status == 'accepted' ||
                  status == 'declined' ||
                  status == 'withdrawn') {
                throw Exception(
                  'Your previous offer is closed. Create a new offer from a renewed listing.',
                );
              }
            }

            final now = FieldValue.serverTimestamp();
            transaction.set(offerRef, {
              'listingId': listing.id,
              'listingTitle': listing.title,
              'sellerId': listing.sellerId,
              'buyerId': uid,
              'buyerName': buyerName,
              'amount': amount,
              'history': existing == null
                  ? [
                      {'by': uid, 'amount': amount, 'at': now},
                    ]
                  : FieldValue.arrayUnion([
                      {'by': uid, 'amount': amount},
                    ]),
              'message': message.trim(),
              'status': 'pending',
              'createdAt': existing == null
                  ? now
                  : existing['createdAt'] ?? now,
              'updatedAt': now,
            }, SetOptions(merge: true));
          })
          .timeout(const Duration(seconds: 8));
      return true;
    } on TimeoutException {
      error = 'The request took too long. Check your connection and try again.';
      return false;
    } on Exception catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> transition(MarketOffer offer, String action) async {
    if (offer.isExpired &&
        (action == 'accept' ||
            action == 'counter' ||
            action == 'acceptCounter')) {
      error = 'This offer has expired';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _db.runTransaction((transaction) async {
        final offerRef = _db.collection('offers').doc(offer.id);
        final offerSnap = await transaction.get(offerRef);
        if (!offerSnap.exists) throw Exception('Offer no longer exists');
        final current = offerSnap.data()!;
        final listingRef = _db.collection('listings').doc(current['listingId']);
        final listingSnap = await transaction.get(listingRef);
        if (!listingSnap.exists) throw Exception('Listing no longer exists');

        if (action == 'accept') {
          if (current['status'] != 'pending' &&
              current['status'] != 'countered') {
            throw Exception('This offer is no longer actionable');
          }
          transaction.update(offerRef, {
            'status': 'accepted',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          transaction.update(listingRef, {
            'status': 'reserved',
            'reservedFor': current['buyerId'],
          });
          final others = await _db
              .collection('offers')
              .where('listingId', isEqualTo: current['listingId'])
              .where('status', whereIn: ['pending', 'countered'])
              .get();
          for (final doc in others.docs) {
            if (doc.id != offer.id) {
              transaction.update(doc.reference, {
                'status': 'declined',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        } else if (action == 'decline' || action == 'withdraw') {
          final status = action == 'withdraw' ? 'withdrawn' : 'declined';
          transaction.update(offerRef, {
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (action == 'counter') {
          throw Exception('Enter a counter amount before continuing');
        } else if (action == 'acceptCounter') {
          if (current['status'] != 'countered') {
            throw Exception('This counter is no longer actionable');
          }
          transaction.update(offerRef, {
            'status': 'accepted',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          transaction.update(listingRef, {
            'status': 'reserved',
            'reservedFor': current['buyerId'],
          });
        }
      });
      return true;
    } on Exception catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> counterOffer(MarketOffer offer, int amount) async {
    if (amount <= 0) {
      error = 'Counter offer must be greater than zero';
      notifyListeners();
      return false;
    }
    busy = true;
    notifyListeners();
    try {
      await _db.runTransaction((transaction) async {
        final ref = _db.collection('offers').doc(offer.id);
        final snap = await transaction.get(ref);
        if (!snap.exists) throw Exception('Offer no longer exists');
        if (snap.data()?['status'] != 'pending') {
          throw Exception('This offer is no longer pending');
        }
        transaction.update(ref, {
          'amount': amount,
          'status': 'countered',
          'updatedAt': FieldValue.serverTimestamp(),
          'history': FieldValue.arrayUnion([
            {'by': FirebaseAuth.instance.currentUser!.uid, 'amount': amount},
          ]),
        });
      });
      return true;
    } on Exception catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _madeSub?.cancel();
    _receivedSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}

class RatingProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  bool busy = false;
  String? error;

  Future<bool> rateSale({
    required String listingId,
    required String sellerId,
    required int stars,
    String comment = '',
  }) async {
    if (stars < 1 || stars > 5) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final buyerId = FirebaseAuth.instance.currentUser!.uid;
      await _db.runTransaction((transaction) async {
        final ratingRef = _db.collection('ratings').doc(listingId);
        final ratingSnap = await transaction.get(ratingRef);
        if (ratingSnap.exists)
          throw Exception('This sale has already been rated');
        final sellerRef = _db.collection('users').doc(sellerId);
        final sellerSnap = await transaction.get(sellerRef);
        final seller = sellerSnap.data() ?? {};
        transaction.set(ratingRef, {
          'sellerId': sellerId,
          'buyerId': buyerId,
          'stars': stars,
          'comment': comment.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(sellerRef, {
          'ratingSum': ((seller['ratingSum'] as num?)?.toInt() ?? 0) + stars,
          'ratingCount': ((seller['ratingCount'] as num?)?.toInt() ?? 0) + 1,
        }, SetOptions(merge: true));
      });
      return true;
    } on Exception catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
