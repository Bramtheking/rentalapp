import 'package:cloud_firestore/cloud_firestore.dart';

class RentalModel {
  final String id;
  final String name;
  final String address;
  final String? description;
  final int totalUnits;
  final DateTime? createdAt;
  final bool isActive;

  RentalModel({
    required this.id,
    required this.name,
    required this.address,
    this.description,
    required this.totalUnits,
    this.createdAt,
    required this.isActive,
  });

  // Create RentalModel from Firestore document
  factory RentalModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return RentalModel(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      description: data['description'],
      totalUnits: data['totalUnits'] ?? 0,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] ?? true,
    );
  }

  // Convert RentalModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'description': description,
      'totalUnits': totalUnits,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'isActive': isActive,
    };
  }
}