import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/commercial/production_review_status_envelope.dart';
import 'firebase_ready.dart';
import 'production_review_status_validator.dart';

/// Snapshot of production_review_status reads (admin client, no writes).
class ProductionReviewStatusQueryResult {
  const ProductionReviewStatusQueryResult({
    this.envelopes = const [],
    this.malformedCount = 0,
    this.errorMessage = '',
    this.loading = false,
  });

  final List<ProductionReviewStatusEnvelope> envelopes;
  final int malformedCount;
  final String errorMessage;
  final bool loading;

  bool get hasError => errorMessage.trim().isNotEmpty;
  bool get isEmpty => !loading && !hasError && envelopes.isEmpty;
}

/// Firestore `production_review_status` read-only repository.
///
/// Client never writes. Functions/Admin SDK remain the write path.
class ProductionReviewStatusRepository {
  ProductionReviewStatusRepository({
    this._db,
    List<ProductionReviewStatusEnvelope>? memorySeed,
    bool? forceMemory,
  }) : _forceMemory = forceMemory ?? false,
       _memory = List<ProductionReviewStatusEnvelope>.from(
         memorySeed ?? const [],
       );

  final FirebaseFirestore? _db;
  final bool _forceMemory;
  final List<ProductionReviewStatusEnvelope> _memory;
  final _memoryController =
      StreamController<ProductionReviewStatusQueryResult>.broadcast();

  static const collectionName = 'production_review_status';
  static const defaultLimit = 40;

  bool get usesMemory => _forceMemory || !isFirebaseReady();

  CollectionReference<Map<String, dynamic>>? get _col {
    if (usesMemory) return null;
    final db = _db ?? FirebaseFirestore.instance;
    return db.collection(collectionName);
  }

  /// Recent envelopes ordered by updatedAt desc (bounded).
  Stream<ProductionReviewStatusQueryResult> watchRecent({
    int limit = defaultLimit,
  }) {
    final capped = limit.clamp(1, 100);
    if (usesMemory || _col == null) {
      return _watchMemory();
    }

    return _col!
        .orderBy('updatedAt', descending: true)
        .limit(capped)
        .snapshots()
        .map(_parseSnapshot)
        .handleError((Object error, StackTrace _) {
          debugPrint('production_review_status watchRecent: $error');
          return ProductionReviewStatusQueryResult(
            errorMessage: '제작 검토 상태를 불러오지 못했습니다.',
          );
        });
  }

  /// Single instruction stream (deep link / detail).
  Stream<ProductionReviewStatusEnvelope?> watchByInstructionId(
    String instructionId,
  ) {
    final id = instructionId.trim();
    if (id.isEmpty) {
      return Stream<ProductionReviewStatusEnvelope?>.value(null);
    }
    if (usesMemory || _col == null) {
      ProductionReviewStatusEnvelope? found;
      for (final e in _memory) {
        if (e.instructionId == id) {
          found = e;
          break;
        }
      }
      return Stream<ProductionReviewStatusEnvelope?>.value(found);
    }

    return _col!
        .doc(id)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return null;
          return _parseDoc(snap.id, snap.data());
        })
        .handleError((Object error, StackTrace _) {
          debugPrint('production_review_status watchByInstructionId: $error');
          return null;
        });
  }

  Stream<ProductionReviewStatusQueryResult> _watchMemory() {
    scheduleMicrotask(() {
      if (!_memoryController.isClosed) {
        _memoryController.add(
          ProductionReviewStatusQueryResult(envelopes: List.of(_memory)),
        );
      }
    });
    return _memoryController.stream;
  }

  /// Test helper: replace memory seed and notify listeners.
  void setMemoryEnvelopes(List<ProductionReviewStatusEnvelope> next) {
    _memory
      ..clear()
      ..addAll(next);
    if (!_memoryController.isClosed) {
      _memoryController.add(
        ProductionReviewStatusQueryResult(envelopes: List.of(_memory)),
      );
    }
  }

  ProductionReviewStatusQueryResult _parseSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final byInstruction = <String, ProductionReviewStatusEnvelope>{};
    var malformed = 0;
    for (final doc in snap.docs) {
      try {
        final parsed = _parseDoc(doc.id, doc.data());
        if (parsed == null) {
          malformed += 1;
          continue;
        }
        final prev = byInstruction[parsed.instructionId];
        if (prev == null || _isNewer(parsed, prev)) {
          byInstruction[parsed.instructionId] = parsed;
        }
      } catch (e) {
        malformed += 1;
        debugPrint('production_review_status skip ${doc.id}: $e');
      }
    }
    final list = byInstruction.values.toList()
      ..sort((a, b) {
        final at = DateTime.tryParse(
          a.updatedAt.isNotEmpty ? a.updatedAt : a.emittedAt,
        );
        final bt = DateTime.tryParse(
          b.updatedAt.isNotEmpty ? b.updatedAt : b.emittedAt,
        );
        if (at != null && bt != null) return bt.compareTo(at);
        return b.revisionRank.compareTo(a.revisionRank);
      });
    return ProductionReviewStatusQueryResult(
      envelopes: list,
      malformedCount: malformed,
    );
  }

  ProductionReviewStatusEnvelope? _parseDoc(
    String docId,
    Map<String, dynamic>? data,
  ) {
    if (data == null || data.isEmpty) return null;
    final envelope = ProductionReviewStatusEnvelope.fromJson({
      ...data,
      if ('${data['instructionId'] ?? ''}'.trim().isEmpty)
        'instructionId': docId,
    });
    final validation = ProductionReviewStatusValidator.validate(
      incoming: envelope,
    );
    if (!validation.ok && !validation.duplicate) {
      return null;
    }
    if (envelope.schemaVersion !=
        ProductionReviewStatusEnvelope.kSchemaVersion) {
      return null;
    }
    if (envelope.instructionId.trim().isEmpty) return null;
    return envelope;
  }

  static bool _isNewer(
    ProductionReviewStatusEnvelope candidate,
    ProductionReviewStatusEnvelope stored,
  ) {
    if (candidate.revisionRank != stored.revisionRank) {
      return candidate.revisionRank > stored.revisionRank;
    }
    return !candidate.isStaleVs(stored);
  }

  void dispose() {
    _memoryController.close();
  }
}
