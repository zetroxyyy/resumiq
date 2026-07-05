import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigInit {
  static bool _initialized = false;
  
  static Future<void> initializeOnce() async {
    if (_initialized) return;
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 15),
      minimumFetchInterval: Duration.zero,
    ));
    await rc.fetchAndActivate();
    _initialized = true;
  }
}
