import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tenant_model.dart';

class TenantService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get tenants for a specific rental
  Stream<List<Tenant>> getTenants(String rentalId) {
    return _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('tenants')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Tenant.fromFirestore(doc))
            .toList());
  }

  // Get active tenants only
  Stream<List<Tenant>> getActiveTenants(String rentalId) {
    print('DEBUG: Querying tenants with status=active + orderBy createdAt desc');
    return _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('tenants')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
          print('ERROR in getActiveTenants: $error');
          if (error.toString().contains('index')) {
            print('INDEX REQUIRED: Create composite index for status (Ascending) + createdAt (Descending)');
          }
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => Tenant.fromFirestore(doc))
            .toList());
  }

  // Add new tenant
  Future<void> addTenant(String rentalId, Tenant tenant) async {
    await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('tenants')
        .add(tenant.toFirestore());
  }

  // Update tenant
  Future<void> updateTenant(String rentalId, Tenant tenant) async {
    await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('tenants')
        .doc(tenant.id)
        .update(tenant.toFirestore());
  }

  // Delete tenant
  Future<void> deleteTenant(String rentalId, String tenantId) async {
    await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('tenants')
        .doc(tenantId)
        .delete();
  }

  // Move out tenant
  Future<void> moveOutTenant(String rentalId, String tenantId, DateTime moveOutDate) async {
    await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('tenants')
        .doc(tenantId)
        .update({
      'status': 'moved_out',
      'moveOutDate': Timestamp.fromDate(moveOutDate),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Get tenant statistics
  Future<Map<String, dynamic>> getTenantStats(String rentalId) async {
    final tenantsSnapshot = await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('tenants')
        .get();

    int totalTenants = tenantsSnapshot.docs.length;
    int activeTenants = 0;
    int movedOutTenants = 0;
    double totalRentAmount = 0;

    for (var doc in tenantsSnapshot.docs) {
      final tenant = Tenant.fromFirestore(doc);
      if (tenant.status == 'active') {
        activeTenants++;
        totalRentAmount += tenant.rentAmount;
      } else if (tenant.status == 'moved_out') {
        movedOutTenants++;
      }
    }

    return {
      'totalTenants': totalTenants,
      'activeTenants': activeTenants,
      'movedOutTenants': movedOutTenants,
      'totalRentAmount': totalRentAmount,
      'occupancyRate': totalTenants > 0 ? (activeTenants / totalTenants * 100) : 0,
    };
  }

  // Search tenants
  Future<List<Tenant>> searchTenants(String rentalId, String query) async {
    final snapshot = await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('tenants')
        .get();

    return snapshot.docs
        .map((doc) => Tenant.fromFirestore(doc))
        .where((tenant) =>
            tenant.name.toLowerCase().contains(query.toLowerCase()) ||
            tenant.email.toLowerCase().contains(query.toLowerCase()) ||
            tenant.phone.contains(query) ||
            tenant.unitNumber.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}