import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../shared/widgets/glass_card.dart';

/// Recent Activity Item Widget
class RecentActivityItem extends StatelessWidget {
  final String action;
  final String description;
  final DateTime timestamp;

  const RecentActivityItem({super.key, required this.action, required this.description, required this.timestamp});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildActionIcon(action),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          SizedBox(width: 8),
          Text(_formatTimestamp(timestamp), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildActionIcon(String action) {
    IconData icon;
    switch (action.toLowerCase()) {
      case 'payment received':
        icon = Icons.monetization_on_outlined;
        break;
      case 'notification':
        icon = Icons.notifications_outlined;
        break;
      case 'fee paid':
        icon = Icons.check_circle_outline;
        break;
      case 'attendance recorded':
        icon = Icons.person_outline;
        break;
      default:
        icon = Icons.info_outline;
    }
    return Icon(icon, size: 20, color: AppColors.primary);
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays <= 7) return '${difference.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year.toString().substring(2)}';
  }
}

/// System Alert Widget for dashboard warnings/info
class SystemAlert extends StatelessWidget {
  final String message;
  final bool isWarning;

  const SystemAlert({super.key, required this.message, this.isWarning = true});

  @override
  Widget build(BuildContext context) {
    final bgColor = isWarning ? AppColors.warning.withOpacity(0.15) : AppColors.primary.withOpacity(0.15);
    final iconColor = isWarning ? AppColors.warning : AppColors.primary;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      fillColor: bgColor,
      child: Row(
        children: [
          Icon(isWarning ? Icons.warning_rounded : Icons.info_rounded, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isWarning ? AppColors.textSecondary : AppColors.textPrimary))),
        ],
      ),
    );
  }
}
