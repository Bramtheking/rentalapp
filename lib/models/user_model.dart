import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String userType;
  final String displayName;
  final DateTime? createdAt;
  final bool isActive;
  final String? rentalId;
  final String? rentalName;

  UserModel({
    required this.uid,
    required this.email,
    required this.userType,
    required this.displayName,
    this.createdAt,
    required this.isActive,
    this.rentalId,
    this.rentalName,
  });

  // Create UserModel from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      userType: data['userType'] ?? 'rentalmanager',
      displayName: data['displayName'] ?? '',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] ?? true,
      rentalId: data['rentalId'],
      rentalName: data['rentalName'],
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'userType': userType,
      'displayName': displayName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'isActive': isActive,
      'rentalId': rentalId,
      'rentalName': rentalName,
    };
  }

  // Check if user has specific permission
  bool hasPermission(String requiredType) {
    return isActive && (userType == requiredType || userType == 'admin' || userType == 'superadmin');
  }

  // Get user role display name
  String get roleDisplayName {
    switch (userType) {
      case 'rentalmanager':
        return 'Rental Manager';
      case 'editor':
        return 'Editor';
      case 'admin':
        return 'Administrator';
      case 'superadmin':
        return 'Super Administrator';
      default:
        return 'User';
    }
  }

  // Check if user is super admin
  bool get isSuperAdmin => userType == 'superadmin';

  // Get rental display info
  String get rentalDisplayName {
    if (rentalName != null && rentalName!.isNotEmpty) {
      return rentalName!;
    } else if (rentalId != null && rentalId!.isNotEmpty) {
      return 'Rental $rentalId';
    }
    return 'No Rental Assigned';
  }
}