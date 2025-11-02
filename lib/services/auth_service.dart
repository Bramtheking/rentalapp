import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      // First try by document ID (UID)
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      
      // If not found, try searching by UID field
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data() as Map<String, dynamic>?;
      }
      
      // If still not found, try searching by email
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        QuerySnapshot emailQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: currentUser.email)
            .limit(1)
            .get();
        
        if (emailQuery.docs.isNotEmpty) {
          return emailQuery.docs.first.data() as Map<String, dynamic>?;
        }
      }
      
      return null;
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  // Create user document in Firestore (for manual user creation)
  Future<void> createUserDocument({
    required String uid,
    required String email,
    required String userType,
    String? displayName,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'userType': userType,
        'displayName': displayName ?? email.split('@')[0],
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
    } catch (e) {
      throw Exception('Failed to create user document: $e');
    }
  }

  // Check if user has required permissions
  Future<bool> hasPermission(String uid, String requiredType) async {
    try {
      Map<String, dynamic>? userData = await getUserData(uid);
      if (userData == null) return false;
      
      String userType = userData['userType'] ?? '';
      bool isActive = userData['isActive'] ?? false;
      
      return isActive && (userType == requiredType || userType == 'superadmin');
    } catch (e) {
      return false;
    }
  }

  // Assign building to user (for editors)
  Future<void> assignBuildingToUser({
    required String userId,
    required String buildingId,
    required String buildingName,
  }) async {
    try {
      DocumentReference userRef = _firestore.collection('users').doc(userId);
      
      // Get current user data
      DocumentSnapshot userDoc = await userRef.get();
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      
      if (userData == null) {
        throw Exception('User not found');
      }

      // Get current buildings list
      List<String> currentBuildings = [];
      if (userData['buildings'] != null) {
        currentBuildings = List<String>.from(userData['buildings']);
      }
      
      // Add building if not already assigned
      if (!currentBuildings.contains(buildingId)) {
        currentBuildings.add(buildingId);
      }

      // Update user document
      await userRef.update({
        'buildings': currentBuildings,
        'rental': buildingName, // For backward compatibility
        'lastSelectedBuilding': buildingId,
        'lastSelectedBuildingName': buildingName,
      });

    } catch (e) {
      throw Exception('Failed to assign building to user: $e');
    }
  }

  // Remove building from user
  Future<void> removeBuildingFromUser({
    required String userId,
    required String buildingId,
  }) async {
    try {
      DocumentReference userRef = _firestore.collection('users').doc(userId);
      
      // Get current user data
      DocumentSnapshot userDoc = await userRef.get();
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      
      if (userData == null) {
        throw Exception('User not found');
      }

      // Get current buildings list
      List<String> currentBuildings = [];
      if (userData['buildings'] != null) {
        currentBuildings = List<String>.from(userData['buildings']);
      }
      
      // Remove building
      currentBuildings.remove(buildingId);

      // Update user document
      Map<String, dynamic> updateData = {
        'buildings': currentBuildings,
      };

      // If this was the last selected building, clear it
      if (userData['lastSelectedBuilding'] == buildingId) {
        updateData['lastSelectedBuilding'] = null;
        updateData['lastSelectedBuildingName'] = 'Select Building';
        updateData['rental'] = '';
      }

      await userRef.update(updateData);

    } catch (e) {
      throw Exception('Failed to remove building from user: $e');
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }
}