import 'dart:typed_data';

import 'package:get/get.dart';

import '../platform/screen_time_api.dart';

/// App icons, loaded once per app and shared by every screen.
class AppIconCache {
  AppIconCache(this._screenTime);

  final ScreenTimeApi _screenTime;
  final icons = <String, Uint8List>{}.obs;
  final _requested = <String>{};

  void ensure(String packageName) {
    if (!_requested.add(packageName)) return;
    _screenTime.getAppIcon(packageName).then(
      (bytes) {
        if (bytes != null) icons[packageName] = bytes;
      },
      // Icons are cosmetic; the row keeps its placeholder.
      onError: (Object _) {},
    );
  }
}
