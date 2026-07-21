import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/deployed_site.dart';
import '../models/ops_models.dart';

class DeployedSitesRepository {
  DeployedSitesRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _sites =>
      _db.collection('deployed_sites');
  CollectionReference<Map<String, dynamic>> get _activity =>
      _db.collection('activity_logs');
  CollectionReference<Map<String, dynamic>> get _settings =>
      _db.collection('settings');

  Stream<List<DeployedSiteDoc>> watchSites({bool includeInactive = true}) {
    return _sites.snapshots().map((snapshot) {
      final list = snapshot.docs.map(DeployedSiteDoc.fromDoc).toList();
      final filtered = includeInactive
          ? list
          : list.where((s) => s.isActive).toList();
      filtered.sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        if (order != 0) return order;
        return a.nameKo.compareTo(b.nameKo);
      });
      return filtered;
    });
  }

  Future<List<DeployedSiteDoc>> fetchSitesOnce() async {
    final snapshot = await _sites.get();
    return snapshot.docs.map(DeployedSiteDoc.fromDoc).toList();
  }

  Future<bool> isCatalogSeeded() async {
    final snap = await _settings.doc('deployed_sites').get();
    return snap.exists && snap.data()?['seeded'] == true;
  }

  Future<void> markCatalogSeeded({required int count}) async {
    await _settings.doc('deployed_sites').set({
      'seeded': true,
      'seededCount': count,
      'seededAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> existsByLiveUrlOrProjectId({
    required String liveUrl,
    required String firebaseProjectId,
    String? excludeId,
  }) async {
    final url = liveUrl.trim().toLowerCase();
    final projectId = firebaseProjectId.trim().toLowerCase();
    if (url.isEmpty && projectId.isEmpty) return false;

    if (url.isNotEmpty) {
      final byUrl = await _sites
          .where('liveUrl', isEqualTo: liveUrl.trim())
          .limit(5)
          .get();
      if (byUrl.docs.any((d) => d.id != excludeId)) return true;
    }
    if (projectId.isNotEmpty) {
      final byProject = await _sites
          .where('firebaseProjectId', isEqualTo: firebaseProjectId.trim())
          .limit(5)
          .get();
      if (byProject.docs.any((d) => d.id != excludeId)) return true;
    }
    return false;
  }

  Future<String> upsertSite(DeployedSiteDoc site, {bool isNew = false}) async {
    final ref = site.id.isEmpty ? _sites.doc() : _sites.doc(site.id);
    await ref.set(
      site.toMap(includeCreatedAt: isNew || site.id.isEmpty),
      SetOptions(merge: true),
    );
    await _logActivity(
      action: isNew || site.id.isEmpty ? 'create' : 'update',
      documentId: ref.id,
      summary: '배포사이트 저장: ${site.nameKo}',
    );
    return ref.id;
  }

  Future<void> setStatus(String id, String status) async {
    await _sites.doc(id).set({
      'status': status,
      'isActive': status != DeployedSiteStatus.inactive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _logActivity(
      action: 'update',
      documentId: id,
      summary: '배포사이트 상태 변경: $status',
    );
  }

  Future<void> setFavorite(String id, bool value) async {
    await _sites.doc(id).set({
      'isFavorite': value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> recordCheck({
    required String id,
    required String issues,
    required String nextAction,
    required String adminMemo,
    required bool mobileChecked,
    required bool desktopChecked,
    required bool httpsChecked,
    String status = DeployedSiteStatus.operating,
  }) async {
    await _sites.doc(id).set({
      'issues': issues,
      'nextAction': nextAction,
      'adminMemo': adminMemo,
      'mobileChecked': mobileChecked,
      'desktopChecked': desktopChecked,
      'httpsChecked': httpsChecked,
      'status': status,
      'isActive': status != DeployedSiteStatus.inactive,
      'lastCheckedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _logActivity(
      action: 'update',
      documentId: id,
      summary: '배포사이트 점검 기록',
    );
  }

  Future<void> deactivate(String id) async {
    await setStatus(id, DeployedSiteStatus.inactive);
  }

  Future<void> _logActivity({
    required String action,
    required String documentId,
    required String summary,
  }) async {
    final u = _auth.currentUser;
    await _activity.add(
      ActivityLogDoc(
        id: '',
        action: action,
        collection: 'deployed_sites',
        documentId: documentId,
        summary: summary,
        actorUid: u?.uid ?? '',
        actorEmail: u?.email ?? '',
      ).toMap(),
    );
  }
}
