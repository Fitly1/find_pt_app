import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final bool isForce;
  final String latestVersion;
  final String? changelog;
  final Uri storeUri;

  AppUpdateInfo({
    required this.hasUpdate,
    required this.isForce,
    required this.latestVersion,
    required this.storeUri,
    this.changelog,
  });
}

class AppUpdateService {
  static const String _collection = 'app_config';
  static const String _docId = 'fitly';

  static const String _dismissedKey = 'dismissed_update_version';

  /// Compare "1.0.4" style version strings
  static int _compareVersions(String a, String b) {
    final pa = a.split('.').map(int.parse).toList();
    final pb = b.split('.').map(int.parse).toList();
    final maxLen = pa.length > pb.length ? pa.length : pb.length;

    for (int i = 0; i < maxLen; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  /// Raw info from Firestore, ignoring "remind me later".
  static Future<AppUpdateInfo?> _loadFromRemote() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version; // e.g. "1.0.4"

    final doc = await FirebaseFirestore.instance
        .collection(_collection)
        .doc(_docId)
        .get();

    if (!doc.exists) return null;
    final data = doc.data() ?? {};

    final latest = (data['latest_version'] as String?) ?? currentVersion;
    final min = (data['min_version'] as String?) ?? currentVersion;
    final changelog = data['changelog'] as String?;
    final playUrl = data['play_store_url'] as String?;
    final appStoreUrl = data['app_store_url'] as String?;

    final needsUpdate = _compareVersions(currentVersion, latest) < 0;
    final isForce = _compareVersions(currentVersion, min) < 0;

    if (!needsUpdate) return null;

    final storeUrl = Platform.isIOS ? appStoreUrl : playUrl;
    if (storeUrl == null || storeUrl.isEmpty) return null;

    return AppUpdateInfo(
      hasUpdate: true,
      isForce: isForce,
      latestVersion: latest,
      storeUri: Uri.parse(storeUrl),
      changelog: changelog,
    );
  }

  /// Info taking "remind me later" into account.
  static Future<AppUpdateInfo?> getEffectiveUpdateInfo() async {
    final info = await _loadFromRemote();
    if (info == null) return null;

    // Force updates ignore "remind me later"
    if (info.isForce) return info;

    final prefs = await SharedPreferences.getInstance();
    final dismissedVersion = prefs.getString(_dismissedKey);

    if (dismissedVersion == info.latestVersion) {
      // User tapped "Not now" for this version
      return null;
    }
    return info;
  }

  static Future<void> markVersionDismissed(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedKey, version);
  }

  static Future<void> openStore(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
