import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pathwise/models/goal_model.dart';
import 'package:pathwise/models/user_model.dart';
import 'package:pathwise/screens/auth_page.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class ProfilePage extends StatefulWidget {
  final String uid;

  const ProfilePage({super.key, required this.uid});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserModel? _viewedUserModel;
  UserModel? _currentUserModel;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final viewedUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();

      if (mounted && viewedUserDoc.exists) {
        _viewedUserModel = UserModel.fromFirestore(viewedUserDoc);
      } else if (mounted) {
        _error = 'User not found.';
      }

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (mounted && currentUserId != null) {
        final currentUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
        if (currentUserDoc.exists) {
          _currentUserModel = UserModel.fromFirestore(currentUserDoc);
        }
      }
    } catch (e) {
      if (mounted) _error = 'Failed to load user data: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthPage()),
            (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
    }
  }

  Widget _buildAvatar(String? photoURL, String? displayName) {
    if (photoURL != null && photoURL.isNotEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundColor: Colors.grey[200],
        backgroundImage: NetworkImage(photoURL),
      );
    }
    return CircleAvatar(radius: 48, child: _initialsAvatar(displayName));
  }

  Widget _initialsAvatar(String? displayName) {
    final initials = (displayName ?? '')
        .trim()
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0])
        .take(2)
        .join()
        .toUpperCase();
    return Text(initials.isEmpty ? '?' : initials,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold));
  }

  Stream<QuerySnapshot> _getShareRequests() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('share_requests')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _acceptRequest(String requestId, Map<String, dynamic> goalData) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final newGoal = Goal(
        id: const Uuid().v4(),
        title: goalData['title'] ?? 'No Title',
        steps: (goalData['steps'] as List<dynamic>?)
            ?.map((stepData) => GoalStep.fromFirestore(stepData))
            .toList() ??
            [],
        recurrence: goalData['recurrence'] ?? 'none',
        reminder: (goalData['reminder'] as Timestamp?)?.toDate(),
      );

      await Hive.box<Goal>('goalsBox').put(newGoal.id, newGoal);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('goals')
          .doc(newGoal.id)
          .set(newGoal.toFirestore());

      await _declineRequest(requestId);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal accepted!')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to accept goal: $e')));
    }
  }

  Future<void> _declineRequest(String requestId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('share_requests')
        .doc(requestId)
        .delete();
  }

  Future<void> _toggleBlockUser(String userToBlockId, String userToBlockName) async {
    final currentUserId = _currentUserModel?.uid;
    if (currentUserId == null) return;
    final isBlocked =
        _currentUserModel?.blockedUsers.contains(userToBlockId) ?? false;

    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isBlocked ? 'Unblock User?' : 'Block User?'),
          content: Text(
              'Are you sure you want to ${isBlocked ? 'unblock' : 'block'} $userToBlockName?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(isBlocked ? 'Unblock' : 'Block')),
          ],
        ));
    if (confirm != true) return;

    final newBlockedList = List<String>.from(_currentUserModel!.blockedUsers);
    if (isBlocked) {
      newBlockedList.remove(userToBlockId);
    } else {
      newBlockedList.add(userToBlockId);
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .update({'blockedUsers': newBlockedList});

    await _loadAllData(); // Refresh user data
  }

  void _showRequestPreviewDialog(Map<String, dynamic> requestData, String requestId) async {
    final goalData = requestData['goal'] as Map<String, dynamic>? ?? {};
    final senderId = requestData['senderId'] as String?;

    if (senderId == null) return;

    // Fetch sender's full user model for their photoURL
    final senderDoc = await FirebaseFirestore.instance.collection('users').doc(senderId).get();
    final sender = senderDoc.exists ? UserModel.fromFirestore(senderDoc) : null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Goal Preview'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sender != null)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // Close the dialog
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(uid: senderId)));
                    },
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            _buildAvatar(sender.photoURL, sender.displayName),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sender.displayName ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const Text('Tap to view profile', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const Divider(height: 24),
                Text(
                  goalData['title'] ?? 'Untitled Goal',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...?((goalData['steps'] as List<dynamic>?)
                    ?.map((step) => Text('• ${step['title'] ?? ''}'))
                    .toList()),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _acceptRequest(requestId, goalData);
              },
              child: const Text('Accept'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _declineRequest(requestId);
              },
              child: const Text('Decline'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
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

    if (_error != null || _viewedUserModel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile Error')),
        body: Center(
            child: Text(_error ?? 'Could not load user profile.',
                style: const TextStyle(color: Colors.red))),
      );
    }

    final viewedUser = _viewedUserModel!;
    final isCurrentUser = FirebaseAuth.instance.currentUser?.uid == widget.uid;
    final isBlockedByCurrentUser =
        _currentUserModel?.blockedUsers.contains(viewedUser.uid) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCurrentUser
            ? 'My Profile'
            : (viewedUser.displayName ?? 'Profile')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildAvatar(viewedUser.photoURL, viewedUser.displayName),
                const SizedBox(height: 12),
                Text(viewedUser.displayName ?? 'No display name',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(viewedUser.email ?? 'No email',
                    style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          ),
          if (isCurrentUser)
            Expanded(child: _buildShareRequestSection())
          else
            const Spacer(),
          if (!isCurrentUser)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () => _toggleBlockUser(
                    viewedUser.uid, viewedUser.displayName ?? 'this user'),
                icon: Icon(
                    isBlockedByCurrentUser ? Icons.check_circle : Icons.block),
                label: Text(isBlockedByCurrentUser ? 'Unblock User' : 'Block User'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: isBlockedByCurrentUser
                        ? Colors.grey[300]
                        : Colors.amber.shade100,
                    foregroundColor: isBlockedByCurrentUser
                        ? Colors.black54
                        : Colors.amber.shade800),
              ),
            ),
          if (isCurrentUser)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShareRequestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Shared Goal Requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const Divider(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getShareRequests(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Text('You have no new goal requests.'));
              }
              final requests = snapshot.data!.docs;
              return ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final requestDoc = requests[index];
                  final request = requestDoc.data() as Map<String, dynamic>;
                  final goalData =
                      request['goal'] as Map<String, dynamic>? ?? {};
                  return GestureDetector(
                    onLongPress: () => _showRequestPreviewDialog(request, requestDoc.id),
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text(goalData['title'] ?? 'Untitled Goal'),
                        subtitle: Text('From: ${request['senderName']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              tooltip: 'Accept',
                              onPressed: () =>
                                  _acceptRequest(requestDoc.id, goalData),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: 'Decline',
                              onPressed: () => _declineRequest(requestDoc.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

