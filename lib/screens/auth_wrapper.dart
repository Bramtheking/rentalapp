import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'super_admin_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  // Auto-create user document ONLY if it doesn't exist
  Future<void> _createUserDocumentIfNotExists(User user) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        // Document doesn't exist - create it
        await docRef.set({
          'email': user.email,
          'userType': 'rentalmanager', // Default role for new users only
          'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'User',
          'isActive': true,
          'rental': '', // Empty rental field - admin will assign later
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('✅ New user document created for ${user.email}');
      } else {
        print('✅ User document already exists for ${user.email} - not overwriting');
        
        // Check if user has rental field and auto-create rental document (but not for superadmin)
        final userData = docSnapshot.data() as Map<String, dynamic>;
        final userType = userData['userType'] as String?;
        final rentalName = userData['rental'] as String?;
        
        // Only rentalmanager can auto-create rentals
        if (userType == 'rentalmanager' && rentalName != null && rentalName.isNotEmpty) {
          await _createRentalDocumentIfNotExists(rentalName, user.uid);
        }
      }
    } catch (e) {
      print('❌ Error checking/creating user document: $e');
    }
  }

  // Auto-create rental document based on user's rental field
  Future<void> _createRentalDocumentIfNotExists(String rentalName, String userId) async {
    try {
      final rentalDocRef = FirebaseFirestore.instance.collection('rentals').doc(rentalName);
      final rentalSnapshot = await rentalDocRef.get();
      
      if (!rentalSnapshot.exists) {
        // Create new rental document
        await rentalDocRef.set({
          'name': rentalName,
          'address': 'To be updated',
          'totalUnits': 0,
          'description': 'Auto-created rental',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': userId,
          'ownerId': userId,
          // Nested collections will be created as subcollections
          'payments': {},
          'tenants': {},
          'units': {},
          'expenses': {},
        });
        // Auto-created rental document silently
      } else {
        // Rental document already exists
      }
    } catch (e) {
      print('❌ Error creating rental document: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // Debug: Print connection state
        print('AuthWrapper - Connection State: ${snapshot.connectionState}');
        print('AuthWrapper - Has Data: ${snapshot.hasData}');
        print('AuthWrapper - Data: ${snapshot.data}');
        print('AuthWrapper - Error: ${snapshot.error}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                  SizedBox(height: 16),
                  Text('Initializing...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Force rebuild
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const AuthWrapper()),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // User is signed in - CHECK ROLE AND ROUTE ACCORDINGLY
          print('🔥 LOGGED IN USER UID: ${snapshot.data!.uid}');
          print('🔥 LOGGED IN USER EMAIL: ${snapshot.data!.email}');
          
          // Auto-create user document ONLY if it doesn't exist (fire and forget)
          _createUserDocumentIfNotExists(snapshot.data!);
          
          // Check user role and route accordingly
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, userDoc) {
              if (userDoc.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                  ),
                );
              }
              
              if (userDoc.hasData && userDoc.data!.exists) {
                final userData = userDoc.data!.data() as Map<String, dynamic>;
                final userType = userData['userType'] ?? 'rentalmanager';
                final rentalName = userData['rental'] as String?;
                
                print('🔥 USER TYPE: $userType');
                print('🔥 RENTAL NAME: $rentalName');
                
                // Route based on user type
                if (userType == 'superadmin') {
                  // SuperAdmin goes to admin dashboard - no rental creation
                  return const SuperAdminDashboard();
                } else if (userType == 'rentalmanager') {
                  // RentalManager can always access HomeScreen and create buildings
                  return const HomeScreen();
                } else if (userType == 'editor') {
                  // Editor can access HomeScreen but won't see buildings until assigned
                  return const HomeScreen();
                } else {
                  // Default case - allow access to HomeScreen
                  return const HomeScreen();
                }
              } else {
                // Document doesn't exist yet (still being created) - default to HomeScreen
                return const HomeScreen();
              }
            },
          );
        } else {
          // User is not signed in
          print('User is not signed in, showing login screen');
          return const LoginScreen();
        }
      },
    );
  }
}

class NoRentalAssignedScreen extends StatelessWidget {
  const NoRentalAssignedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange, Colors.deepOrange],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.business_center,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                const Text(
                  'No Rental Assigned',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You have not been assigned to any rental property yet. Please contact your administrator to assign you to a rental property.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    await AuthService().signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RentalNotFoundScreen extends StatelessWidget {
  const RentalNotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange, Colors.deepOrange],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Rental Property Not Found',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'The rental property assigned to you does not exist yet. Please contact a Rental Manager to create the rental property first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    await AuthService().signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}