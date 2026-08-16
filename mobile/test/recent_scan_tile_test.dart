import 'package:agrisense_ai/models/diagnosis_prediction.dart';
import 'package:agrisense_ai/models/scan_record.dart';
import 'package:agrisense_ai/widgets/recent_scan_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ScanRecord _scanCapturedAgo(Duration ago, {String classId = 'tomato_healthy'}) {
  return ScanRecord(
    id: 'scan-1',
    imagePath: '/tmp/leaf.jpg',
    prediction: DiagnosisPrediction(classId: classId, confidence: 0.9),
    capturedAt: DateTime.now().subtract(ago),
  );
}

Future<void> _pump(WidgetTester tester, ScanRecord scan) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: RecentScanTile(scan: scan, onTap: () {})),
    ),
  );
}

void main() {
  testWidgets('shows "just now" for a scan captured under a minute ago', (
    tester,
  ) async {
    await _pump(tester, _scanCapturedAgo(const Duration(seconds: 10)));
    expect(find.text('just now'), findsOneWidget);
  });

  testWidgets('shows minutes ago for a scan captured under an hour ago', (
    tester,
  ) async {
    await _pump(tester, _scanCapturedAgo(const Duration(minutes: 5)));
    expect(find.text('5m ago'), findsOneWidget);
  });

  testWidgets('shows hours ago for a scan captured under a day ago', (
    tester,
  ) async {
    await _pump(tester, _scanCapturedAgo(const Duration(hours: 3)));
    expect(find.text('3h ago'), findsOneWidget);
  });

  testWidgets('shows days ago for a scan captured over a day ago', (
    tester,
  ) async {
    await _pump(tester, _scanCapturedAgo(const Duration(days: 2)));
    expect(find.text('2d ago'), findsOneWidget);
  });

  testWidgets('tapping the tile calls onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecentScanTile(
            scan: _scanCapturedAgo(const Duration(seconds: 1)),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ListTile));

    expect(tapped, isTrue);
  });
}
