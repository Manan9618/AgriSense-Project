import 'package:flutter/material.dart';

import '../models/scan_record.dart';
import '../theme/app_theme.dart';

class RecentScanTile extends StatelessWidget {
  const RecentScanTile({super.key, required this.scan, required this.onTap});

  final ScanRecord scan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: scan.isHealthy
            ? AppTheme.lightGreenBg
            : const Color(0xFFFBE9E7),
        child: Text(
          scan.cropLabel.substring(0, 1),
          style: TextStyle(
            color: scan.isHealthy
                ? AppTheme.primaryGreen
                : AppTheme.highUrgency,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text('${scan.cropLabel} — ${scan.conditionLabel}'),
      subtitle: Text(_relativeTime(scan.capturedAt)),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
