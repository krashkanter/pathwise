import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoURL;
  final List<String> blockedUsers;

  UserModel({
    required this.uid,
    this.displayName,
    this.email,
    this.photoURL,
    this.blockedUsers = const [],
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel(
      uid: doc.id,
      displayName: data['displayName'] as String?,
      email: data['email'] as String?,
      photoURL: data['photoURL'] as String?,
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
    );
  }

  // Converts the UserModel instance to a map.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'blockedUsers': blockedUsers,
    };
  }
}

