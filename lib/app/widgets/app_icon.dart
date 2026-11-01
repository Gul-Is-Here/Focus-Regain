import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/app_icon_cache.dart';

class AppIcon extends StatelessWidget {
  const AppIcon(this.packageName, {super.key, this.size = 40});

  final String packageName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cache = Get.find<AppIconCache>()..ensure(packageName);
    return SizedBox.square(
      dimension: size,
      child: Obx(() {
        final icon = cache.icons[packageName];
        return icon == null
            ? const Icon(Icons.apps)
            : Image.memory(icon, gaplessPlayback: true);
      }),
    );
  }
}
