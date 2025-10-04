// lib/screens/profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pathwise/models/user_model.dart';
import 'package:pathwise/screens/auth_page.dart';

import 'package:share_plus/share_plus.dart';

class ProfilePage extends StatefulWidget {
  final String uid;
  final VoidCallback? onSignedOut;

  const ProfilePage({super.key, required this.uid, this.onSignedOut});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserModel? _userModel; // Use our custom user model
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUser(widget.uid);
  }

  Future<void> _loadUser(String uid) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (mounted && doc.exists) {
        setState(() {
          _userModel = UserModel.fromFirestore(doc);
        });
      } else if (mounted) {
        setState(() {
          _error = 'User not found.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load user: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (widget.onSignedOut != null) {
        widget.onSignedOut!();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => AuthPage()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
    }
  }

  Widget _buildAvatar(String? photoURL, String? displayName) {
    if (photoURL != null && photoURL.isNotEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: NetworkImage(photoURL),
        backgroundColor: Colors.grey[200],
      );
    }
    // Fallback to initials
    final initials = (displayName ?? '')
        .trim()
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0])
        .take(2)
        .join()
        .toUpperCase();
    return CircleAvatar(
      radius: 48,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _userModel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile Error')),
        body: Center(
          child: Text(
            _error ?? 'Could not load user profile.',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final user = _userModel!;
    // Check if the profile being viewed is the currently logged-in user
    final bool isCurrentUser =
        FirebaseAuth.instance.currentUser?.uid == widget.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isCurrentUser ? 'My Profile' : (user.displayName ?? 'Profile'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAvatar(user.photoURL, user.displayName),
            const SizedBox(height: 12),
            Text(
              user.displayName ?? 'No display name',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              user.email ?? 'No email',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.fingerprint_rounded),
                title: const Text('Share User ID'),
                // subtitle: Text(user.uid),
                trailing: IconButton(
                  icon: const Icon(Icons.share_rounded),
                  onPressed: () {
                    final uidToShare =
                        FirebaseAuth.instance.currentUser?.uid ?? user.uid;
                    final uri = Uri.https('pathwise.com', 'user/$uidToShare');
                    final params = ShareParams(uri: uri);
                    SharePlus.instance.share(params);
                  },
                ),
              ),
            ),
            const Spacer(),
            if (isCurrentUser)
              ElevatedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
