import 'package:flutter/material.dart';

class EmployeeTile extends StatelessWidget {
  final Map<String, dynamic> employee;
  final VoidCallback? onEditTap; // ← NEW: edit button callback

  const EmployeeTile({
    super.key,
    required this.employee,
    this.onEditTap, // ← optional: admin passes this, employee view doesn't
  });

  String? _statusLabel(String? status) {
    switch (status) {
      case 'present':
        return '● Present';
      case 'wfh':
        return '● WFH';
      case 'absent':
        return '● Absent';
      default:
        return null;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'wfh':
        return Colors.blue;
      case 'absent':
        return Colors.red;
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = employee['full_name'] ?? 'Unknown';
    final email = employee['email'] ?? '';
    final department = employee['department'] ?? 'General';
    final status = employee['status'] as String?;
    final avatarUrl = employee['avatar_url'] as String?;
    final isLate = employee['is_late'] as bool? ?? false;
    final totalHours = (employee['total_hours'] as num?)?.toDouble();
    final label = _statusLabel(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email, style: const TextStyle(fontSize: 12)),
            Text(
              department,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 4),

            // ── Status + Late + Hours badges ──────────────────
            // WHY row: shows all info compactly in one line
            Row(
              children: [
                if (label != null)
                  Text(
                    label,
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                // ── Late badge ───────────────────────────────
                if (isLate && status != 'absent') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      '⚠️ Late',
                      style: TextStyle(fontSize: 10, color: Colors.amber),
                    ),
                  ),
                ],
                // ── Hours badge ──────────────────────────────
                if (totalHours != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '🕐 ${totalHours.toStringAsFixed(1)}h',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),

        // ── Edit button (only shown if onEditTap provided) ────
        // WHY trailing icon not text: cleaner — saves space
        // WHY only when onEditTap set: same tile works for
        // both admin (with edit) and employee views (no edit)
        trailing: onEditTap != null
            ? IconButton(
                icon: const Icon(Icons.edit_rounded),
                color: Theme.of(context).colorScheme.primary,
                tooltip: 'Edit Attendance',
                onPressed: onEditTap,
              )
            : null,
      ),
    );
  }
}
