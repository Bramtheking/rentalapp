import 'package:cloud_firestore/cloud_firestore.dart';

class Tenant {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String unitNumber;
  final double rentAmount;
  final DateTime moveInDate;
  final DateTime? moveOutDate;
  final String status; // 'active', 'moved_out', 'pending'
  final String? emergencyContact;
  final String? emergencyPhone;
  final double? securityDeposit;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Tenant({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.unitNumber,
    required this.rentAmount,
    required this.moveInDate,
    this.moveOutDate,
    required this.status,
    this.emergencyContact,
    this.emergencyPhone,
    this.securityDeposit,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Tenant.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Tenant(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      unitNumber: data['unitNumber'] ?? '',
      rentAmount: (data['rentAmount'] ?? 0).toDouble(),
      moveInDate: (data['moveInDate'] as Timestamp).toDate(),
      moveOutDate: data['moveOutDate'] != null 
          ? (data['moveOutDate'] as Timestamp).toDate() 
          : null,
      status: data['status'] ?? 'active',
      emergencyContact: data['emergencyContact'],
      emergencyPhone: data['emergencyPhone'],
      securityDeposit: data['securityDeposit']?.toDouble(),
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'unitNumber': unitNumber,
      'rentAmount': rentAmount,
      'moveInDate': Timestamp.fromDate(moveInDate),
      'moveOutDate': moveOutDate != null ? Timestamp.fromDate(moveOutDate!) : null,
      'status': status,
      'emergencyContact': emergencyContact,
      'emergencyPhone': emergencyPhone,
      'securityDeposit': securityDeposit,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Tenant copyWith({
    String? name,
    String? email,
    String? phone,
    String? unitNumber,
    double? rentAmount,
    DateTime? moveInDate,
    DateTime? moveOutDate,
    String? status,
    String? emergencyContact,
    String? emergencyPhone,
    double? securityDeposit,
    String? notes,
  }) {
    return Tenant(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      unitNumber: unitNumber ?? this.unitNumber,
      rentAmount: rentAmount ?? this.rentAmount,
      moveInDate: moveInDate ?? this.moveInDate,
      moveOutDate: moveOutDate ?? this.moveOutDate,
      status: status ?? this.status,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      securityDeposit: securityDeposit ?? this.securityDeposit,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}