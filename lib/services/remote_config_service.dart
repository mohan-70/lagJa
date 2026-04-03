import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  static final FirebaseRemoteConfig _remoteConfig =
      FirebaseRemoteConfig.instance;

  /// The AI API key fetched from Firebase Remote Config.
  static String get aiApiKey =>
      _remoteConfig.getString('gemini_api_key');

  /// Initialize Remote Config with defaults and fetch latest values.
  static Future<void> initialize() async {
    try {
      debugPrint('[RemoteConfig] Starting initialization...');

      // Set in-app defaults (empty key until fetched)
      await _remoteConfig.setDefaults(const {
        'gemini_api_key': '',
      });
      debugPrint('[RemoteConfig] Defaults set.');

      // Configure fetch interval (0 for debug to always fetch fresh)
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(hours: 1),
      ));
      debugPrint('[RemoteConfig] Settings configured '
          '(minimumFetchInterval: ${kDebugMode ? "0 (debug)" : "1 hour"}).');

      // Fetch and activate
      final bool activated = await _remoteConfig.fetchAndActivate();
      debugPrint('[RemoteConfig] fetchAndActivate returned: $activated');

      // Log the actual value (masked for security)
      final key = aiApiKey;
      if (key.isEmpty) {
        debugPrint('[RemoteConfig] ⚠️ API key is EMPTY!');
        debugPrint('[RemoteConfig] Check that the parameter name in '
            'Firebase Console is exactly: gemini_api_key');
      } else {
        debugPrint('[RemoteConfig] ✅ API key loaded '
            '(${key.length} chars, starts with: ${key.substring(0, 4)}...)');
      }

      // Check the source of the value
      final value = _remoteConfig.getValue('gemini_api_key');
      debugPrint('[RemoteConfig] Value source: ${value.source}');

      // Listen for real-time config updates
      _remoteConfig.onConfigUpdated.listen((event) async {
        debugPrint('[RemoteConfig] Real-time update received for: '
            '${event.updatedKeys}');
        await _remoteConfig.activate();
        debugPrint('[RemoteConfig] Activated after real-time update. '
            'Key present: ${aiApiKey.isNotEmpty}');
      });
    } catch (e, stackTrace) {
      debugPrint('[RemoteConfig] ❌ Initialization failed: $e');
      debugPrint('[RemoteConfig] Stack trace: $stackTrace');
    }
  }
}
