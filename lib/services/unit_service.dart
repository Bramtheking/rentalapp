import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/unit_model.dart';

class UnitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get units for a specific rental
  Stream<List<Unit>> getUnits(String rentalId) {
    return _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('units')
        .orderBy('unitNumber')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Unit.fromFirestore(doc))
            .toList());
  }

  // Get units by status
  Stream<List<Unit>> getUnitsByStatus(String rentalId, String status) {
    print('DEBUG: Querying units with status=$status + orderBy unitNumber');
    return _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('units')
        .where('status', isEqualTo: status)
        .orderBy('unitNumber')
        .snapshots()
        .handleError((error) {
          print('ERROR in getUnitsByStatus: $error');
          if (error.toString().contains('index')) {
            print('INDEX REQUIRED: Create composite index for status (Ascending) + unitNumber (Ascending)');
          }
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => Unit.fromFirestore(doc))
            .toList());
  }

  // Add new unit
  Future<void> addUnit(String rentalId, Unit unit) async {
    await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('units')
        .add(unit.toFirestore());
  }

  // Update unit
  Future<void> updateUnit(String rentalId, Unit unit) async {
    await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('units')
        .doc(unit.id)
        .update(unit.toFirestore());
  }

  // Delete unit
  Future<void> deleteUnit(String rentalId, String unitDocId) async {
    await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('units')
        .doc(unitDocId)
        .delete();
  }

  // Assign tenant to unit
  Future<void> assignTenant(String rentalId, String unitDocId, String tenantId, String tenantName) async {
    await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('units')
        .doc(unitDocId)
        .update({
      'tenantId': tenantId,
      'tenantName': tenantName,
      'status': 'occupied',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Remove tenant from unit
  Future<void> removeTenant(String rentalId, String unitDocId) async {
    await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('units')
        .doc(unitDocId)
        .update({
      'tenantId': null,
      'tenantName': null,
      'status': 'vacant',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Get unit statistics
  Future<Map<String, dynamic>> getUnitStats(String rentalId) async {
    final unitsSnapshot = await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('units')
        .get();

    int totalUnits = unitsSnapshot.docs.length;
    int occupiedUnits = 0;
    int vacantUnits = 0;
    int underMaintenance = 0;
    double totalRent = 0;
    double occupiedRent = 0;

    for (var doc in unitsSnapshot.docs) {
      final unit = Unit.fromFirestore(doc);
      totalRent += unit.rent;
      
      switch (unit.status) {
        case 'occupied':
          occupiedUnits++;
          occupiedRent += unit.rent;
          break;
        case 'vacant':
          vacantUnits++;
          break;
        case 'under_maintenance':
          underMaintenance++;
          break;
      }
    }

    double occupancyRate = totalUnits > 0 ? (occupiedUnits / totalUnits * 100) : 0;

    return {
      'totalUnits': totalUnits,
      'occupiedUnits': occupiedUnits,
      'vacantUnits': vacantUnits,
      'underMaintenance': underMaintenance,
      'occupancyRate': occupancyRate,
      'totalRent': totalRent,
      'occupiedRent': occupiedRent,
      'potentialRent': totalRent - occupiedRent,
    };
  }

  // Search units
  Future<List<Unit>> searchUnits(String rentalId, String query) async {
    final snapshot = await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('units')
        .get();

    return snapshot.docs
        .map((doc) => Unit.fromFirestore(doc))
        .where((unit) =>
            unit.unitNumber.toLowerCase().contains(query.toLowerCase()) ||
            unit.unitName.toLowerCase().contains(query.toLowerCase()) ||
            unit.type.toLowerCase().contains(query.toLowerCase()) ||
            (unit.tenantName?.toLowerCase().contains(query.toLowerCase()) ?? false))
        .toList();
  }

  // DAMAGE CONTROL METHODS

  // Get damage reports for a rental
  Stream<List<DamageReport>> getDamageReports(String rentalId) {
    return _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('damage_reports')
        .orderBy('dateReported', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DamageReport.fromFirestore(doc))
            .toList());
  }

  // Get damage reports by status
  Stream<List<DamageReport>> getDamageReportsByStatus(String rentalId, String status) {
    return _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('damage_reports')
        .where('status', isEqualTo: status)
        .orderBy('dateReported', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DamageReport.fromFirestore(doc))
            .toList());
  }

  // Add damage report
  Future<void> addDamageReport(String rentalId, DamageReport report) async {
    await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('damage_reports')
        .add(report.toFirestore());
  }

  // Update damage report
  Future<void> updateDamageReport(String rentalId, DamageReport report) async {
    await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('damage_reports')
        .doc(report.id)
        .update(report.toFirestore());
  }

  // Delete damage report
  Future<void> deleteDamageReport(String rentalId, String reportId) async {
    await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('damage_reports')
        .doc(reportId)
        .delete();
  }

  // Get damage statistics
  Future<Map<String, dynamic>> getDamageStats(String rentalId) async {
    final reportsSnapshot = await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('damage_reports')
        .get();

    int totalReports = reportsSnapshot.docs.length;
    int pendingReports = 0;
    int inProgressReports = 0;
    int repairedReports = 0;
    double totalRepairCost = 0;

    for (var doc in reportsSnapshot.docs) {
      final report = DamageReport.fromFirestore(doc);
      
      switch (report.status) {
        case 'pending':
          pendingReports++;
          break;
        case 'in_progress':
          inProgressReports++;
          break;
        case 'repaired':
          repairedReports++;
          break;
      }
      
      if (report.repairCost != null) {
        totalRepairCost += report.repairCost!;
      }
    }

    return {
      'totalReports': totalReports,
      'pendingReports': pendingReports,
      'inProgressReports': inProgressReports,
      'repairedReports': repairedReports,
      'totalRepairCost': totalRepairCost,
    };
  }

  // Generate next damage ID
  Future<String> generateDamageId(String rentalId) async {
    final snapshot = await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('damage_reports')
        .get();
    
    int nextNumber = snapshot.docs.length + 1;
    return 'D${nextNumber.toString().padLeft(3, '0')}';
  }
}