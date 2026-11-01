import 'package:get/get.dart';

import '../../data/models/blocking_rules.dart';
import '../../data/models/installed_app.dart';
import '../blocking/blocking_view_model.dart';

class ScheduleEditorViewModel extends GetxController {
  ScheduleEditorViewModel(this._blocking, this.existing);

  final BlockingViewModel _blocking;

  /// Null when creating a new schedule.
  final BlockSchedule? existing;

  late final name = (existing?.name ?? 'Work hours').obs;
  late final days = {...existing?.days ?? weekdays}.obs;
  late final startMinute = (existing?.startMinute ?? 9 * 60).obs;
  late final endMinute = (existing?.endMinute ?? 17 * 60).obs;
  late final packages = {...?existing?.packages}.obs;
  final query = ''.obs;

  List<InstalledApp> get visibleApps {
    final q = query.value.trim().toLowerCase();
    final apps = _blocking.apps;
    if (q.isEmpty) return apps;
    return apps
        .where(
          (a) =>
              a.label.toLowerCase().contains(q) ||
              a.category.label.toLowerCase().contains(q),
        )
        .toList();
  }

  bool get isOvernight => endMinute.value <= startMinute.value;

  /// Length of the window in minutes; overnight windows wrap past midnight.
  int get durationMinutes => (endMinute.value - startMinute.value) % (24 * 60);

  static const weekdays = {1, 2, 3, 4, 5};
  static const everyDay = {1, 2, 3, 4, 5, 6, 7};

  void setDays(Set<int> next) => days.assignAll(next);

  /// True when every app in the current search results is picked.
  bool get allVisibleSelected =>
      visibleApps.isNotEmpty &&
      visibleApps.every((a) => packages.contains(a.packageName));

  /// Picks every app in the search results, or clears them if all are picked.
  void toggleAllVisible() {
    final visible = visibleApps.map((a) => a.packageName).toSet();
    allVisibleSelected ? packages.removeAll(visible) : packages.addAll(visible);
  }

  bool get canSave =>
      name.value.trim().isNotEmpty &&
      days.isNotEmpty &&
      startMinute.value != endMinute.value &&
      packages.isNotEmpty;

  void toggleDay(int day) =>
      days.contains(day) ? days.remove(day) : days.add(day);

  void toggleApp(String packageName) => packages.contains(packageName)
      ? packages.remove(packageName)
      : packages.add(packageName);

  Future<void> save() async {
    if (!canSave) return;
    await _blocking.saveSchedule(
      BlockSchedule(
        id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.value.trim(),
        days: days.toSet(),
        startMinute: startMinute.value,
        endMinute: endMinute.value,
        packages: packages.toSet(),
      ),
    );
    Get.back<void>();
  }

  Future<void> delete() async {
    final id = existing?.id;
    if (id != null) await _blocking.deleteSchedule(id);
    Get.back<void>();
  }
}
