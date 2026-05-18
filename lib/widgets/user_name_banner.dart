import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';

class UserNameBanner extends StatefulWidget {
  const UserNameBanner({super.key});

  @override
  State<UserNameBanner> createState() => _UserNameBannerState();
}

class _UserNameBannerState extends State<UserNameBanner> {
  late final Future<UserProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = UserProfileService().fetchDefaultProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        Widget child;
        if (snapshot.connectionState == ConnectionState.waiting) {
          child = const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        } else if (snapshot.hasError) {
          child = const Text(
            'User lädt nicht',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          );
        } else {
          final name = snapshot.data?.name.trim();
          child = Text(
            name?.isNotEmpty == true ? name! : 'User',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          );
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 18, color: Colors.white70),
                const SizedBox(width: 8),
                child,
              ],
            ),
          ),
        );
      },
    );
  }
}
