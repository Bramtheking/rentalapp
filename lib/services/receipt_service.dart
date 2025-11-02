import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tenant_model.dart';

class ReceiptService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate receipt data
  Future<Map<String, dynamic>> generateReceipt({
    required String buildingId,
    required String tenantId,
    required double amount,
    required String paymentMethod,
    required DateTime paymentDate,
    String? reference,
    Map<String, double>? breakdown,
  }) async {
    try {
      // Get tenant information
      DocumentSnapshot tenantDoc = await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('tenants')
          .doc(tenantId)
          .get();

      if (!tenantDoc.exists) {
        throw Exception('Tenant not found');
      }

      Tenant tenant = Tenant.fromFirestore(tenantDoc);

      // Get building information
      DocumentSnapshot buildingDoc = await _firestore
          .collection('rentals')
          .doc(buildingId)
          .get();

      if (!buildingDoc.exists) {
        throw Exception('Building not found');
      }

      Map<String, dynamic> buildingData = buildingDoc.data() as Map<String, dynamic>;

      // Generate receipt number
      String receiptNo = _generateReceiptNumber();

      // Create receipt data
      Map<String, dynamic> receiptData = {
        'receiptNo': receiptNo,
        'date': paymentDate.toIso8601String(),
        'tenant': {
          'name': tenant.name,
          'email': tenant.email,
          'phone': tenant.phone,
          'unitNumber': tenant.unitNumber,
        },
        'building': {
          'name': buildingData['name'] ?? 'Unknown Building',
          'address': buildingData['address'] ?? 'Unknown Address',
        },
        'payment': {
          'amount': amount,
          'method': paymentMethod,
          'reference': reference,
          'breakdown': breakdown ?? {'Rent': amount},
        },
        'generatedAt': DateTime.now().toIso8601String(),
      };

      // Save receipt to Firestore
      await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('receipts')
          .doc(receiptNo)
          .set(receiptData);

      return receiptData;
    } catch (e) {
      throw Exception('Failed to generate receipt: $e');
    }
  }

  // Generate receipt number
  String _generateReceiptNumber() {
    DateTime now = DateTime.now();
    String timestamp = now.millisecondsSinceEpoch.toString();
    return 'RCP${timestamp.substring(timestamp.length - 8)}';
  }

  // Generate receipt text for copying/sharing
  String generateReceiptText(Map<String, dynamic> receiptData) {
    StringBuffer receipt = StringBuffer();
    
    receipt.writeln('═══════════════════════════════════════');
    receipt.writeln('              PAYMENT RECEIPT');
    receipt.writeln('═══════════════════════════════════════');
    receipt.writeln();
    
    // Receipt details
    receipt.writeln('Receipt No: ${receiptData['receiptNo']}');
    receipt.writeln('Date: ${_formatDate(DateTime.parse(receiptData['date']))}');
    receipt.writeln();
    
    // Building information
    receipt.writeln('PROPERTY DETAILS:');
    receipt.writeln('Building: ${receiptData['building']['name']}');
    receipt.writeln('Address: ${receiptData['building']['address']}');
    receipt.writeln();
    
    // Tenant information
    receipt.writeln('TENANT DETAILS:');
    receipt.writeln('Name: ${receiptData['tenant']['name']}');
    receipt.writeln('Unit: ${receiptData['tenant']['unitNumber']}');
    receipt.writeln('Phone: ${receiptData['tenant']['phone']}');
    receipt.writeln('Email: ${receiptData['tenant']['email']}');
    receipt.writeln();
    
    // Payment details
    receipt.writeln('PAYMENT DETAILS:');
    receipt.writeln('Method: ${receiptData['payment']['method']}');
    if (receiptData['payment']['reference'] != null) {
      receipt.writeln('Reference: ${receiptData['payment']['reference']}');
    }
    receipt.writeln();
    
    // Payment breakdown
    receipt.writeln('PAYMENT BREAKDOWN:');
    receipt.writeln('─────────────────────────────────────');
    
    Map<String, dynamic> breakdown = receiptData['payment']['breakdown'];
    double total = 0;
    
    breakdown.forEach((key, value) {
      double amount = (value as num).toDouble();
      total += amount;
      receipt.writeln('${key.padRight(25)} KES ${amount.toStringAsFixed(2).padLeft(10)}');
    });
    
    receipt.writeln('─────────────────────────────────────');
    receipt.writeln('${'TOTAL'.padRight(25)} KES ${total.toStringAsFixed(2).padLeft(10)}');
    receipt.writeln('═══════════════════════════════════════');
    receipt.writeln();
    
    receipt.writeln('Thank you for your payment!');
    receipt.writeln();
    receipt.writeln('Generated on: ${_formatDate(DateTime.parse(receiptData['generatedAt']))}');
    receipt.writeln('═══════════════════════════════════════');
    
    return receipt.toString();
  }

  // Format date for display
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Get receipts for a building
  Future<List<Map<String, dynamic>>> getReceipts(String buildingId, {int limit = 50}) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('receipts')
          .orderBy('generatedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Failed to get receipts: $e');
    }
  }

  // Copy receipt to clipboard
  Future<void> copyReceiptToClipboard(Map<String, dynamic> receiptData) async {
    String receiptText = generateReceiptText(receiptData);
    await Clipboard.setData(ClipboardData(text: receiptText));
  }

  // Get receipt by number
  Future<Map<String, dynamic>?> getReceiptByNumber(String buildingId, String receiptNo) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('receipts')
          .doc(receiptNo)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get receipt: $e');
    }
  }
}