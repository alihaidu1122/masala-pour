import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../storage/save_service.dart';
import 'save_merge.dart';

/// Backs up the local save to Firestore and restores it after a reinstall.
///
/// - Signs in anonymously (silently, no UI).
/// - The backup lives at `players/{key}`, where `key` is a SHA-256 hash of a
///   phone id that survives uninstall/reinstall (Android ANDROID_ID; on iOS a
///   random id kept in the Keychain). The anonymous user id is NOT used as
///   the key because it changes after a reinstall.
/// - Nothing is uploaded until the backup has been checked once, so a fresh
///   install can never overwrite a player's cloud progress.
class CloudSaveService with WidgetsBindingObserver {
  CloudSaveService._();

  /// Shared instance.
  static final CloudSaveService instance = CloudSaveService._();

  static const _channel = MethodChannel('masala/device_id');
  static const _salt = 'masala-pour-backup-v1';

  DocumentReference<Map<String, dynamic>>? _doc;
  bool _restoreChecked = false;
  Timer? _debounce;

  /// Whether cloud backup is running.
  bool get isActive => _doc != null && _restoreChecked;

  /// Starts Firebase, signs in, and restores this phone's backup.
  ///
  /// Returns true when the local save changed because the cloud was ahead.
  /// Safe to call on unsupported platforms (does nothing).
  Future<bool> startAndRestore() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return false;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) await auth.signInAnonymously();

      final stableId = await _channel.invokeMethod<String>('getStableId');
      if (stableId == null || stableId.isEmpty) return false;
      final key = sha256.convert(utf8.encode('$_salt:$stableId')).toString();
      _doc = FirebaseFirestore.instance.collection('players').doc(key);

      WidgetsBinding.instance.addObserver(this);
      SaveService.onChanged = scheduleUpload;
      return await _restore();
    } catch (e) {
      debugPrint('CloudSave: start failed: $e');
      return false;
    }
  }

  Future<bool> _restore() async {
    final doc = _doc;
    if (doc == null) return false;
    try {
      final snap = await doc.get(const GetOptions(source: Source.server));
      _restoreChecked = true;
      final save = SaveService.instance;
      final local = save.exportSnapshot();
      final raw = snap.data()?['save'];
      if (raw is! Map) {
        // No backup yet: upload this phone's progress.
        unawaited(uploadNow());
        return false;
      }
      final cloud = <String, Object>{
        for (final e in raw.entries)
          if (e.value != null) '${e.key}': e.value as Object,
      };
      final merged = SaveMerge.merge(local, cloud);
      final changed = {
        for (final e in merged.entries)
          if (!_same(local[e.key], e.value)) e.key: e.value,
      };
      if (changed.isNotEmpty) await save.importSnapshot(changed);
      unawaited(uploadNow());
      return SaveMerge.cloudIsAhead(local, cloud);
    } catch (e) {
      debugPrint('CloudSave: restore failed: $e');
      return false;
    }
  }

  static bool _same(Object? a, Object? b) {
    if (a is List && b is List) return listEquals(a, b);
    return a == b;
  }

  /// Uploads a few seconds after the last change (batches rapid changes).
  void scheduleUpload() {
    if (!isActive) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), uploadNow);
  }

  /// Uploads the full local save now.
  Future<void> uploadNow() async {
    final doc = _doc;
    if (doc == null || !_restoreChecked) return;
    _debounce?.cancel();
    try {
      final save = SaveService.instance;
      final snapshot = {
        for (final e in save.exportSnapshot().entries)
          if (!e.key.startsWith('restarts_') &&
              !e.key.startsWith('level_undos_'))
            e.key: e.value,
      };
      await doc.set({
        'save': snapshot,
        'level': save.currentLevel,
        'coins': save.coins,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'uid': FirebaseAuth.instance.currentUser?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('CloudSave: upload failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_debounce?.isActive ?? false) unawaited(uploadNow());
    }
  }
}
