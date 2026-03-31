import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ← NEW import
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/theme_provider.dart'; // ← NEW import
import '../../data/profile_repository.dart';

// ← CHANGED: StatefulWidget → ConsumerStatefulWidget
//   WHY: needs ref.watch(themeModeProvider) for dark mode toggle
//   StatefulWidget has no access to Riverpod ref
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

// ← CHANGED: State → ConsumerState (matches ConsumerStatefulWidget)
class _ProfilePageState extends ConsumerState<ProfilePage> {
  Map<String, dynamic>? profile;
  Map<String, dynamic>? summary;
  bool isLoading = true;
  bool isUploading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        profileRepository.getProfile(),
        profileRepository.getAttendanceSummary(),
      ]);
      if (mounted) {
        setState(() {
          profile = results[0] as Map<String, dynamic>;
          summary = results[1] as Map<String, dynamic>;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  // ── pickAndUploadAvatar() ──────────────────────────────────
  Future<void> pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => isUploading = true);
    try {
      final url = await profileRepository.uploadAvatar(
        imageFile: File(picked.path),
      );
      if (mounted) {
        setState(() {
          profile?['avatar_url'] = url;
          isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── showEditSheet() ────────────────────────────────────────
  void showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EditProfileSheet(
        currentName: profile?['full_name'] as String? ?? '',
        currentDepartment: profile?['department'] as String? ?? '',
        onSaved: (name, dept) {
          setState(() {
            profile?['full_name'] = name;
            profile?['department'] = dept;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  // ── showChangePasswordSheet() ──────────────────────────────
  void showChangePasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ChangePasswordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ← NEW: watch theme mode for toggle switch state
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        // ← CHANGED: 'My Profile' → 'Profile'
        //   WHY: HomePage AppBar already hides on profile tab —
        //   no double header. 'Profile' is cleaner, shorter
        title: const Text('Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: loadAll,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: loadAll,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Avatar + Info card ─────────────
                    _AvatarCard(
                      profile: profile!,
                      isUploading: isUploading,
                      onEditAvatar: pickAndUploadAvatar,
                      onEditProfile: showEditSheet,
                    ),
                    const SizedBox(height: 20),

                    // ── Attendance summary ─────────────
                    if (summary != null) ...[
                      _SectionHeader(
                        icon: Icons.bar_chart_rounded,
                        title:
                            'This Month · '
                            '${summary!['month_label']}',
                      ),
                      const SizedBox(height: 12),
                      _AttendanceSummaryGrid(summary: summary!),
                      const SizedBox(height: 20),
                    ],

                    // ── Appearance section ─────────────
                    // ← NEW: dark mode toggle section
                    const _SectionHeader(
                      icon: Icons.palette_rounded,
                      title: 'Appearance',
                    ),
                    const SizedBox(height: 12),

                    // ← NEW: Dark mode toggle tile
                    // WHY InkWell not _SettingsTile: toggle
                    //   needs a Switch widget on trailing —
                    //   _SettingsTile only has chevron
                    _DarkModeTile(isDark: isDark),
                    const SizedBox(height: 20),

                    // ── Account section ────────────────
                    const _SectionHeader(
                      icon: Icons.manage_accounts_rounded,
                      title: 'Account',
                    ),
                    const SizedBox(height: 12),

                    // Edit profile
                    _SettingsTile(
                      icon: Icons.edit_rounded,
                      iconColor: Colors.blue,
                      title: 'Edit Profile',
                      subtitle: 'Update name and department',
                      onTap: showEditSheet,
                    ),
                    const SizedBox(height: 10),

                    // Change password
                    _SettingsTile(
                      icon: Icons.lock_outline_rounded,
                      iconColor: Colors.orange,
                      title: 'Change Password',
                      subtitle: 'Update your login password',
                      onTap: showChangePasswordSheet,
                    ),
                    const SizedBox(height: 10),

                    // Sign out
                    _SettingsTile(
                      icon: Icons.logout_rounded,
                      iconColor: Colors.red,
                      title: 'Sign Out',
                      subtitle: 'Log out of your account',
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          useRootNavigator: true,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Text('Sign Out'),
                            content: const Text(
                              'Are you sure you want '
                              'to sign out?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(
                                  ctx,
                                  rootNavigator: true,
                                ).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(
                                  ctx,
                                  rootNavigator: true,
                                ).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Sign Out'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await Supabase.instance.client.auth.signOut();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── _DarkModeTile ─────────────────────────────────────────────
// ← NEW widget
// PURPOSE: Toggle dark/light mode + persist via Hive
// WHY Consumer here not in parent: isolates rebuild to just
//   this tile — parent ProfilePage doesn't rebuild on toggle
class _DarkModeTile extends ConsumerWidget {
  final bool isDark;
  const _DarkModeTile({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => ref.read(themeModeProvider.notifier).toggle(),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Icon ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                size: 18,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(width: 14),

            // ── Label ────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dark Mode',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    isDark ? 'Dark theme active' : 'Light / System theme',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),

            // ── Switch ───────────────────────────────────
            // WHY Switch not IconButton: visually communicates
            //   on/off state — clearer than a toggle icon
            Switch(
              value: isDark,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _AvatarCard ───────────────────────────────────────────────
class _AvatarCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final bool isUploading;
  final VoidCallback onEditAvatar;
  final VoidCallback onEditProfile;

  const _AvatarCard({
    required this.profile,
    required this.isUploading,
    required this.onEditAvatar,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile['full_name'] as String? ?? 'Unknown';
    final email = profile['email'] as String? ?? '';
    final department = profile['department'] as String? ?? '';
    final role = profile['role'] as String? ?? 'employee';
    final avatarUrl = profile['avatar_url'] as String?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // ── Avatar with camera overlay ───────────────
          Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.3),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 2.5,
                  ),
                ),
                child: ClipOval(
                  child: avatarUrl != null
                      ? Image.network(
                          // WHY cache bust: ensures re-uploaded
                          // avatar shows immediately without
                          // waiting for HTTP cache to expire
                          '$avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}',
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                    : null,
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => _avatarFallback(name),
                        )
                      : _avatarFallback(name),
                ),
              ),

              // ── Upload loading overlay ───────────────
              if (isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),

              // ── Camera icon ──────────────────────────
              if (!isUploading)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: onEditAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Name ─────────────────────────────────────
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          // ── Email ─────────────────────────────────────
          Text(
            email,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),

          // ── Department + Role row ─────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (department.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.business_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        department,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  role == 'admin' ? 'Admin' : 'Employee',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Edit Profile button ───────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(
                Icons.edit_rounded,
                size: 16,
                color: Colors.white,
              ),
              label: const Text(
                'Edit Profile',
                style: TextStyle(color: Colors.white),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onEditProfile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name) => Container(
    color: Colors.white.withValues(alpha: 0.2),
    child: Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),
  );
}

// ── _AttendanceSummaryGrid ────────────────────────────────────
class _AttendanceSummaryGrid extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _AttendanceSummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                emoji: '🏢',
                label: 'Present',
                value: '${summary['present_days']}',
                unit: 'days',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                emoji: '🏠',
                label: 'Work From Home',
                value: '${summary['wfh_days']}',
                unit: 'days',
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                emoji: '❌',
                label: 'Absent',
                value: '${summary['absent_days']}',
                unit: 'days',
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                emoji: '⏰',
                label: 'Late Arrivals',
                value: '${summary['late_days']}',
                unit: 'times',
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _StatCard(
          emoji: '🕐',
          label: 'Total Hours This Month',
          value: '${summary['total_hours']}',
          unit: 'hrs',
          color: Colors.purple,
          fullWidth: true,
        ),
      ],
    );
  }
}

// ── _StatCard ─────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool fullWidth;

  const _StatCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: fullWidth
          ? Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: color.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        '$value $unit',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── _SectionHeader ────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ── _SettingsTile ─────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ── EditProfileSheet ──────────────────────────────────────────
class EditProfileSheet extends StatefulWidget {
  final String currentName;
  final String currentDepartment;
  final void Function(String name, String dept) onSaved;

  const EditProfileSheet({
    super.key,
    required this.currentName,
    required this.currentDepartment,
    required this.onSaved,
  });

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController nameController;
  late final TextEditingController deptController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.currentName);
    deptController = TextEditingController(text: widget.currentDepartment);
  }

  @override
  void dispose() {
    nameController.dispose();
    deptController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }
    setState(() => isSaving = true);
    try {
      await profileRepository.updateProfile(
        fullName: nameController.text.trim(),
        department: deptController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved(nameController.text.trim(), deptController.text.trim());
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Row(
            children: [
              Icon(Icons.edit_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                'Edit Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Full Name',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Enter your full name',
              prefixIcon: const Icon(Icons.person_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Department',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: deptController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'e.g. Engineering, HR, Finance',
              prefixIcon: const Icon(Icons.business_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(isSaving ? 'Saving...' : 'Save Changes'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isSaving ? null : save,
            ),
          ),
        ],
      ),
    );
  }
}

// ── ChangePasswordSheet ───────────────────────────────────────
class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final currentCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  bool showCurrent = false;
  bool showNew = false;
  bool showConfirm = false;
  bool isSaving = false;

  @override
  void dispose() {
    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final current = currentCtrl.text;
    final newPwd = newCtrl.text;
    final confirm = confirmCtrl.text;

    if (current.isEmpty || newPwd.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }
    if (newPwd != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (newPwd.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      await profileRepository.changePassword(
        currentPassword: current,
        newPassword: newPwd,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSaving = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Text('🔒', style: TextStyle(fontSize: 22)),
                SizedBox(width: 8),
                Text('Password Error', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool showPassword,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: !showPassword,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                showPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
              onPressed: onToggle,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Change Password',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: Colors.blue,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Enter your current password '
                      'to verify, then set a new one.',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _passwordField(
              controller: currentCtrl,
              label: 'Current Password',
              hint: 'Enter current password',
              showPassword: showCurrent,
              onToggle: () => setState(() => showCurrent = !showCurrent),
            ),
            const SizedBox(height: 16),
            _passwordField(
              controller: newCtrl,
              label: 'New Password',
              hint: 'Min 6 characters',
              showPassword: showNew,
              onToggle: () => setState(() => showNew = !showNew),
            ),
            const SizedBox(height: 16),
            _passwordField(
              controller: confirmCtrl,
              label: 'Confirm New Password',
              hint: 'Re-enter new password',
              showPassword: showConfirm,
              onToggle: () => setState(() => showConfirm = !showConfirm),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_reset_rounded),
                label: Text(isSaving ? 'Updating...' : 'Update Password'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isSaving ? null : save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
