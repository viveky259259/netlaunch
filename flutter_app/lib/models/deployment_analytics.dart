class DeploymentAnalytics {
  final String siteId;
  final int totalViews;
  final List<DailyViewData> dailyData;
  final List<PageViewData> topPages;
  final String periodStart;
  final String periodEnd;
  final int periodDays;

  DeploymentAnalytics({
    required this.siteId,
    required this.totalViews,
    required this.dailyData,
    required this.topPages,
    required this.periodStart,
    required this.periodEnd,
    required this.periodDays,
  });

  int get periodViews =>
      dailyData.fold(0, (sum, d) => sum + d.views);

  String get topDevice {
    final totals = <String, int>{};
    for (final d in dailyData) {
      d.devices.forEach((key, value) {
        totals[key] = (totals[key] ?? 0) + value;
      });
    }
    if (totals.isEmpty) return '--';
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final name = sorted.first.key;
    return name[0].toUpperCase() + name.substring(1);
  }

  factory DeploymentAnalytics.fromMap(Map<String, dynamic> map) {
    final period = map['period'] as Map<String, dynamic>? ?? {};
    return DeploymentAnalytics(
      siteId: map['siteId'] as String? ?? '',
      totalViews: map['totalViews'] as int? ?? 0,
      dailyData: (map['dailyData'] as List?)
              ?.map((d) =>
                  DailyViewData.fromMap(d as Map<String, dynamic>))
              .toList() ??
          [],
      topPages: (map['topPages'] as List?)
              ?.map(
                  (d) => PageViewData.fromMap(d as Map<String, dynamic>))
              .toList() ??
          [],
      periodStart: period['start'] as String? ?? '',
      periodEnd: period['end'] as String? ?? '',
      periodDays: period['days'] as int? ?? 30,
    );
  }
}

class DailyViewData {
  final String date;
  final int views;
  final Map<String, int> devices;

  DailyViewData({
    required this.date,
    required this.views,
    required this.devices,
  });

  factory DailyViewData.fromMap(Map<String, dynamic> map) {
    final devicesRaw = map['devices'] as Map<String, dynamic>? ?? {};
    return DailyViewData(
      date: map['date'] as String? ?? '',
      views: map['views'] as int? ?? 0,
      devices: devicesRaw.map((k, v) => MapEntry(k, v as int? ?? 0)),
    );
  }
}

class PageViewData {
  final String path;
  final int views;

  PageViewData({required this.path, required this.views});

  factory PageViewData.fromMap(Map<String, dynamic> map) {
    return PageViewData(
      path: map['path'] as String? ?? '/',
      views: map['views'] as int? ?? 0,
    );
  }
}
