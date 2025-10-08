import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pathwise/models/goal_model.dart';
import '../models/user_model.dart';

class ShareGoalPage extends StatefulWidget {
  final Goal goal;

  const ShareGoalPage({super.key, required this.goal});

  @override
  State<ShareGoalPage> createState() => _ShareGoalPageState();
}

class _ShareGoalPageState extends State<ShareGoalPage> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _searchError;

  Future<void> _sendShareRequest() async {
    if (_emailController.text.isEmpty) return;
    setState(() {
      _isLoading = true;
      _searchError = null;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() => _searchError = 'User not found.');
        return;
      }

      final recipientDoc = querySnapshot.docs.first;
      final recipient = UserModel.fromFirestore(recipientDoc);

      if (recipient.uid == currentUser.uid) {
        setState(() => _searchError = "You can't share a goal with yourself.");
        return;
      }

      if (recipient.blockedUsers.contains(currentUser.uid)) {
        setState(() => _searchError = "This user has blocked you.");
        return;
      }

      // Create a share request in a subcollection of the recipient's document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(recipient.uid)
          .collection('share_requests')
          .add({
        'goal': widget.goal.toFirestore(),
        'senderId': currentUser.uid,
        'senderName': currentUser.displayName ?? 'A user',
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Goal shared with ${recipient.displayName}!')),
      );
      Navigator.pop(context);

    } catch (e) {
      setState(() => _searchError = 'An error occurred. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share Goal')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Sharing goal: "${widget.goal.title}"',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: "Recipient's Email",
                border: const OutlineInputBorder(),
                errorText: _searchError,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
              onPressed: _sendShareRequest,
              icon: const Icon(Icons.send),
              label: const Text('Send Request'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

