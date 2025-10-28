import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new user document manually (for admin use)
  static Future<void> createUserManually({
    required String email,
    required String password,
    required String userType,
    String? displayName,
  }) async {
    try {
      // Create user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'userType': userType,
        'displayName': displayName ?? email.split('@')[0],
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      print('User created successfully: $email');
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  // Create user with rental assignment
  static Future<void> createUserWithRental({
    required String email,
    required String password,
    required String userType,
    String? displayName,
    String? rentalId,
    String? rentalName,
  }) async {
    try {
      // Create user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'userType': userType,
        'displayName': displayName ?? email.split('@')[0],
        'rentalId': rentalId,
        'rentalName': rentalName,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      print('User created successfully: $email');
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  // Update user type
  static Future<void> updateUserType(String uid, String newUserType) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'userType': newUserType,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user type: $e');
      rethrow;
    }
  }

  // Activate/Deactivate user
  static Future<void> toggleUserStatus(String uid, bool isActive) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error toggling user status: $e');
      rethrow;
    }
  }

  // Get all users (for admin dashboard)
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }
}

// Example usage for creating users manually:
/*
To create a rental manager user, you can use this in your admin panel or run it once:

await FirebaseHelper.createUserManually(
  email: 'manager@rental.com',
  password: 'securePassword123',
  userType: 'rentalmanager',
  displayName: 'John Manager',
);

User types:
- 'rentalmanager': Can manage rentals
- 'editor': Can edit content
- 'admin': Full access
*/