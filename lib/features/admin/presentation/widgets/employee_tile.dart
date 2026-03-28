// ============================================================
// employee_tile.dart
// STATUS: Only 3 options — present, wfh, absent
// Employees with no record show nothing in trailing
// ============================================================

import 'package:flutter/material.dart';

class EmployeeTile extends StatelessWidget {
  final Map<String, dynamic> employee;
  const EmployeeTile({super.key, required this.employee});

  // WHY null return: employees without a record today
  // show no status — blank trailing — not misleading
  String? _statusLabel(String? status) {
    switch (status) {
      case 'present':
        return '● Present';
      case 'wfh':
        return '● WFH';
      case 'absent':
        return '● Absent';
      default:
        return null; // no record → show nothing
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
          ],
        ),
        // WHY conditional: only show trailing if status exists
        trailing: label != null
            ? Text(
                label,
                style: TextStyle(
                  color: _statusColor(status),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              )
            : null,
      ),
    );
  }
}
