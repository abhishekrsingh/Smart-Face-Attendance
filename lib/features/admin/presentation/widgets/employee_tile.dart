import 'package:flutter/material.dart';

class EmployeeTile extends StatelessWidget {
  final Map<String, dynamic> employee;
  final VoidCallback? onEditTap;

  const EmployeeTile({super.key, required this.employee, this.onEditTap});

  String? _statusLabel(String? status) => switch (status) {
    'present' => '● Present',
    'wfh' => '● WFH',
    'absent' => '● Absent',
    _ => null,
  };

  Color _statusColor(String? status) => switch (status) {
    'present' => Colors.green,
    'wfh' => Colors.blue,
    'absent' => Colors.red,
    _ => Colors.transparent,
  };

  @override
  Widget build(BuildContext context) {
    final name = employee['full_name'] as String? ?? 'Unknown';
    final email = employee['email'] as String? ?? '';
    final department = employee['department'] as String? ?? 'General';
    final status = employee['status'] as String?;
    final avatarUrl = employee['avatar_url'] as String?;
    final isLate = employee['is_late'] as bool? ?? false;
    final totalHours = (employee['total_hours'] as num?)?.toDouble();
    final label = _statusLabel(status);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Avatar ──────────────────────────────────────
            // WHY manual ClipOval not CircleAvatar.backgroundImage:
            //   CircleAvatar has no errorBuilder — broken images
            //   throw an exception and crash the tile silently.
            //   ClipOval + Image.network gives full control over
            //   loading spinner and error fallback
            _EmployeeAvatar(
              avatarUrl: avatarUrl,
              initial: initial,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 14),

            // ── Name / Email / Department / Badges ───────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Name ──────────────────────────────────
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),

                  // ── Email ──────────────────────────────────
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),

                  // ── Department ────────────────────────────
                  Text(
                    department,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ── Status / Late / Hours badges ──────────
                  // WHY Wrap not Row: Row overflows when all
                  //   three badges appear together — Wrap
                  //   automatically moves to next line if needed
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Status badge
                      if (label != null)
                        Text(
                          label,
                          style: TextStyle(
                            color: _statusColor(status),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),

                      // Late badge
                      if (isLate && status != 'absent')
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

                      // Hours badge
                      if (totalHours != null)
                        Text(
                          '🕐 ${totalHours.toStringAsFixed(1)}h',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),

                      // Not marked badge
                      if (status == null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            '⏳ Not marked',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Edit button ──────────────────────────────────
            // WHY only when onEditTap set: same widget works
            //   for both admin (edit visible) and employee
            //   history view (no edit button)
            if (onEditTap != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 20),
                color: Theme.of(context).colorScheme.primary,
                tooltip: 'Edit Attendance',
                onPressed: onEditTap,
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── _EmployeeAvatar ───────────────────────────────────────────
// PURPOSE: Robust avatar with loading spinner + error fallback
// WHY not CircleAvatar.backgroundImage: no errorBuilder exists
//   on CircleAvatar — failed images crash the tile silently
class _EmployeeAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initial;
  final Color color;

  const _EmployeeAvatar({
    required this.avatarUrl,
    required this.initial,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? Image.network(
                avatarUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                // WHY loadingBuilder: shows spinner while
                //   image downloads — no blank/broken flash
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                        ),
                      ),
                // WHY errorBuilder: shows initial letter
                //   instead of broken image icon when URL
                //   is invalid or network fails
                errorBuilder: (_, __, ___) => _fallback(color),
              )
            : _fallback(color),
      ),
    );
  }

  Widget _fallback(Color color) => Container(
    color: color.withValues(alpha: 0.08),
    child: Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    ),
  );
}
