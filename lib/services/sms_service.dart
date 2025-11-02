import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/sms_format_model.dart';
import '../models/tenant_model.dart';

class SMSService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Platform detection
  bool get isWeb => kIsWeb;
  bool get isMobile => !kIsWeb;
  
  // HostPinnacle SMS API Configuration
  static const String _apiKey = '3f91356dbd39607ae29e3bfcc65c79998e4c524f';
  static const String _baseUrl = 'https://sms.hostpinnacle.co.ke/api/services/sendsms/';
  static const String _senderName = 'HOSTPINNACLE'; // Default sender name
  
  // Hardcoded SMS formats for different banks
  static const Map<String, Map<String, String>> bankFormats = {
    'KCB': {
      'amount': r'Ksh([\d,]+\.?\d*)',
      'reference': r'Ref:\s*([A-Z0-9]+)',
      'date': r'on\s+(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2})',
      'paybill': r'Paybill\s+(\d+)',
    },
    'Family Bank': {
      'amount': r'Ksh([\d,]+\.?\d*)',
      'reference': r'Ref:\s*([A-Z0-9]+)',
      'date': r'on\s+(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2})',
      'paybill': r'Paybill\s+(\d+)',
    },
    'Faulu': {
      'amount': r'Ksh([\d,]+\.?\d*)',
      'reference': r'Ref:\s*([A-Z0-9]+)',
      'date': r'on\s+(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2})',
      'paybill': r'Paybill\s+(\d+)',
    },
    'Equity': {
      'amount': r'Ksh([\d,]+\.?\d*)',
      'reference': r'Ref:\s*([A-Z0-9]+)',
      'date': r'on\s+(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2})',
      'paybill': r'Paybill\s+(\d+)',
    },
    'Co-operative': {
      'amount': r'Ksh([\d,]+\.?\d*)',
      'reference': r'Ref:\s*([A-Z0-9]+)',
      'date': r'on\s+(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2})',
      'paybill': r'Paybill\s+(\d+)',
    },
  };

  // Get available banks
  List<String> getAvailableBanks() {
    return bankFormats.keys.toList();
  }

  // Building-Bank Assignment (using sender name/phone)
  Future<void> assignSenderToBuilding(String buildingId, String senderName) async {
    try {
      await _firestore.collection('rentals').doc(buildingId).update({
        'smsSender': senderName, // This could be "KCB Bank" or "+254722000000"
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to assign sender to building: $e');
    }
  }

  Future<String?> getBuildingSMSSender(String buildingId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('rentals').doc(buildingId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['smsSender'];
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get building SMS sender: $e');
    }
  }
  
  // Detect bank from SMS content or sender
  String? detectBankFromSMS(String smsBody, String? sender) {
    // First try to detect from sender name
    if (sender != null) {
      for (String bank in bankFormats.keys) {
        if (sender.toLowerCase().contains(bank.toLowerCase())) {
          return bank;
        }
      }
    }
    
    // Then try to detect from SMS content
    for (String bank in bankFormats.keys) {
      if (smsBody.toLowerCase().contains(bank.toLowerCase())) {
        return bank;
      }
    }
    
    return null;
  }

  // Payment Structure Management
  Future<void> setPaymentStructure(String buildingId, String unitRef, PaymentStructure structure) async {
    try {
      await _firestore.collection('rentals').doc(buildingId).update({
        'paymentStructure.$unitRef': structure.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to set payment structure: $e');
    }
  }

  Future<Map<String, PaymentStructure>> getPaymentStructures(String buildingId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('rentals').doc(buildingId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> structures = data['paymentStructure'] ?? {};
        
        Map<String, PaymentStructure> result = {};
        structures.forEach((unitRef, structureData) {
          result[unitRef] = PaymentStructure.fromMap(structureData, unitRef);
        });
        return result;
      }
      return {};
    } catch (e) {
      throw Exception('Failed to get payment structures: $e');
    }
  }

  // SMS Transaction Management
  Future<void> saveSMSTransaction(String buildingId, SMSTransaction transaction) async {
    try {
      await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('smsTransactions')
          .doc(transaction.id)
          .set(transaction.toMap());
    } catch (e) {
      throw Exception('Failed to save SMS transaction: $e');
    }
  }

  Future<List<SMSTransaction>> getSMSTransactions(String buildingId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('smsTransactions')
          .orderBy('date', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => 
        SMSTransaction.fromMap(doc.data() as Map<String, dynamic>, doc.id)
      ).toList();
    } catch (e) {
      throw Exception('Failed to get SMS transactions: $e');
    }
  }

  // SMS Parsing using hardcoded formats
  Map<String, String> parseSMS(String smsBody, String? sender) {
    Map<String, String> extracted = {};
    
    // Detect bank first
    String? bank = detectBankFromSMS(smsBody, sender);
    if (bank == null) return extracted;
    
    // Use the detected bank's format
    Map<String, String> format = bankFormats[bank]!;
    
    format.forEach((field, pattern) {
      RegExp regex = RegExp(pattern, caseSensitive: false);
      Match? match = regex.firstMatch(smsBody);
      if (match != null && match.groupCount > 0) {
        extracted[field] = match.group(1)!.replaceAll(',', ''); // Remove commas from amounts
      }
    });
    
    // Add detected bank info
    extracted['bank'] = bank;
    
    return extracted;
  }

  // Extract building and unit from reference
  Map<String, String> extractBuildingAndUnit(String reference) {
    // Extract building prefix (e.g., MERCVENUS from MERCVENUSA11)
    RegExp buildingRegex = RegExp(r'^([A-Z]+)');
    Match? buildingMatch = buildingRegex.firstMatch(reference);
    String building = buildingMatch?.group(1) ?? '';
    
    // Extract unit suffix (e.g., A11 from MERCVENUSA11)
    RegExp unitRegex = RegExp(r'([A-Z0-9]+)$');
    Match? unitMatch = unitRegex.firstMatch(reference.replaceFirst(building, ''));
    String unit = unitMatch?.group(1) ?? '';
    
    return {
      'building': building,
      'unit': unit,
    };
  }

  // Sync start date management
  Future<void> setSyncStartDate(String buildingId, DateTime startDate) async {
    try {
      await _firestore.collection('rentals').doc(buildingId).update({
        'syncStartDate': startDate.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to set sync start date: $e');
    }
  }

  Future<DateTime?> getSyncStartDate(String buildingId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('rentals').doc(buildingId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String? dateStr = data['syncStartDate'];
        if (dateStr != null) {
          return DateTime.parse(dateStr);
        }
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get sync start date: $e');
    }
  }

  // Sync control - only works on mobile
  bool canSync() {
    return isMobile; // Only mobile can sync SMS
  }
  
  String getSyncStatusMessage() {
    if (isWeb) {
      return 'SMS sync is not available on web. Use mobile app for SMS synchronization.';
    }
    return 'SMS sync is available';
  }
  
  // Auto-sync settings
  Future<void> setAutoSyncEnabled(String buildingId, bool enabled) async {
    if (!canSync()) return; // Don't save sync settings on web
    
    try {
      await _firestore.collection('rentals').doc(buildingId).update({
        'autoSyncEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to set auto sync: $e');
    }
  }

  Future<bool> isAutoSyncEnabled(String buildingId) async {
    if (!canSync()) return false; // Always false on web
    
    try {
      DocumentSnapshot doc = await _firestore.collection('rentals').doc(buildingId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['autoSyncEnabled'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Local storage for offline mode (mobile only)
  Future<void> saveSMSToLocal(SMSTransaction transaction) async {
    if (!canSync()) return; // No local storage on web
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> localSMS = prefs.getStringList('pending_sms') ?? [];
      localSMS.add(transaction.rawSMS);
      await prefs.setStringList('pending_sms', localSMS);
    } catch (e) {
      print('Failed to save SMS locally: $e');
    }
  }

  Future<List<String>> getLocalSMS() async {
    if (!canSync()) return []; // No local storage on web
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('pending_sms') ?? [];
    } catch (e) {
      print('Failed to get local SMS: $e');
      return [];
    }
  }

  Future<void> clearLocalSMS() async {
    if (!canSync()) return; // No local storage on web
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_sms');
    } catch (e) {
      print('Failed to clear local SMS: $e');
    }
  }

  // HostPinnacle SMS API Methods
  
  // Send single SMS
  Future<Map<String, dynamic>> sendSMS({
    required String phoneNumber,
    required String message,
    String? customSender,
  }) async {
    try {
      // Clean phone number (remove spaces, dashes, etc.)
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Ensure phone number starts with country code
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '+254${cleanPhone.substring(1)}';
      } else if (!cleanPhone.startsWith('+')) {
        cleanPhone = '+254$cleanPhone';
      }

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'RentalApp/1.0',
        },
        body: jsonEncode({
          'apikey': _apiKey,
          'partnerID': '', // Not required with API key
          'message': message,
          'shortcode': customSender ?? _senderName,
          'mobile': cleanPhone,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        Map<String, dynamic> result = jsonDecode(response.body);
        
        // Check if the API returned an error in the response body
        if (result['status'] == 'error' || result['success'] == false) {
          throw Exception('API Error: ${result['message'] ?? 'Unknown error'}');
        }
        
        // Log SMS to Firestore
        await _logSMSToFirestore(
          phoneNumber: cleanPhone,
          message: message,
          status: 'sent',
          response: result,
        );
        
        return {
          'success': true,
          'message': 'SMS sent successfully',
          'data': result,
        };
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // Log failed SMS
      await _logSMSToFirestore(
        phoneNumber: phoneNumber,
        message: message,
        status: 'failed',
        error: e.toString(),
      );
      
      // Provide more user-friendly error messages
      String userMessage = 'Failed to send SMS';
      if (e.toString().contains('TimeoutException')) {
        userMessage = 'SMS service timeout. Please check your internet connection and try again.';
      } else if (e.toString().contains('SocketException')) {
        userMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('ClientException')) {
        userMessage = 'SMS service unavailable. Please try again later.';
      } else if (e.toString().contains('FormatException')) {
        userMessage = 'Invalid response from SMS service. Please contact support.';
      }
      
      return {
        'success': false,
        'message': userMessage,
        'error': e.toString(),
      };
    }
  }

  // Send bulk SMS
  Future<Map<String, dynamic>> sendBulkSMS({
    required List<String> phoneNumbers,
    required String message,
    String? customSender,
  }) async {
    try {
      List<Map<String, dynamic>> results = [];
      int successCount = 0;
      int failureCount = 0;

      for (String phoneNumber in phoneNumbers) {
        Map<String, dynamic> result = await sendSMS(
          phoneNumber: phoneNumber,
          message: message,
          customSender: customSender,
        );
        
        results.add({
          'phoneNumber': phoneNumber,
          'result': result,
        });
        
        if (result['success']) {
          successCount++;
        } else {
          failureCount++;
        }
        
        // Add small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 500));
      }

      return {
        'success': true,
        'message': 'Bulk SMS completed',
        'totalSent': phoneNumbers.length,
        'successCount': successCount,
        'failureCount': failureCount,
        'results': results,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to send bulk SMS: $e',
        'error': e.toString(),
      };
    }
  }

  // Get SMS balance (if supported by API)
  Future<Map<String, dynamic>> getSMSBalance() async {
    try {
      // HostPinnacle might not have a balance endpoint with just API key
      // This is a placeholder - check their documentation
      return {
        'success': true,
        'balance': 'Unknown', // API key method might not provide balance
        'message': 'Balance check not available with API key method',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get SMS balance: $e',
        'error': e.toString(),
      };
    }
  }

  // Get tenants for SMS targeting
  Future<List<Tenant>> getTenants(String buildingId, {String? filter}) async {
    try {
      Query query = _firestore
          .collection('rentals')
          .doc(buildingId)
          .collection('tenants');

      if (filter == 'active') {
        query = query.where('status', isEqualTo: 'active');
      }

      QuerySnapshot snapshot = await query.get();
      return snapshot.docs.map((doc) => Tenant.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get tenants: $e');
    }
  }

  // Get tenants with arrears for SMS targeting
  Future<List<Tenant>> getTenantsWithArrears(String buildingId) async {
    try {
      // This would need to be implemented based on your payment tracking logic
      // For now, return all tenants - you can enhance this later
      return await getTenants(buildingId, filter: 'active');
    } catch (e) {
      throw Exception('Failed to get tenants with arrears: $e');
    }
  }

  // Send SMS to tenant groups
  Future<Map<String, dynamic>> sendSMSToGroup({
    required String buildingId,
    required String groupType, // 'all', 'active', 'arrears'
    required String message,
    String? customSender,
  }) async {
    try {
      List<Tenant> tenants = [];
      
      switch (groupType) {
        case 'all':
          tenants = await getTenants(buildingId);
          break;
        case 'active':
          tenants = await getTenants(buildingId, filter: 'active');
          break;
        case 'arrears':
          tenants = await getTenantsWithArrears(buildingId);
          break;
        default:
          throw Exception('Invalid group type: $groupType');
      }

      List<String> phoneNumbers = tenants
          .where((tenant) => tenant.phone.isNotEmpty)
          .map((tenant) => tenant.phone)
          .toList();

      if (phoneNumbers.isEmpty) {
        return {
          'success': false,
          'message': 'No phone numbers found for the selected group',
        };
      }

      return await sendBulkSMS(
        phoneNumbers: phoneNumbers,
        message: message,
        customSender: customSender,
      );
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to send SMS to group: $e',
        'error': e.toString(),
      };
    }
  }

  // Process message templates
  String processMessageTemplate(String template, Tenant tenant, {Map<String, String>? customVariables}) {
    String processedMessage = template;
    
    // Replace tenant-specific variables
    processedMessage = processedMessage.replaceAll('[TENANT_NAME]', tenant.name);
    processedMessage = processedMessage.replaceAll('[UNIT_NUMBER]', tenant.unitNumber);
    processedMessage = processedMessage.replaceAll('[AMOUNT]', tenant.rentAmount.toStringAsFixed(0));
    
    // Replace date variables
    DateTime now = DateTime.now();
    processedMessage = processedMessage.replaceAll('[DATE]', '${now.day}/${now.month}/${now.year}');
    processedMessage = processedMessage.replaceAll('[MONTH]', _getMonthName(now.month));
    processedMessage = processedMessage.replaceAll('[TIME]', '${now.hour}:${now.minute.toString().padLeft(2, '0')}');
    
    // Replace custom variables if provided
    if (customVariables != null) {
      customVariables.forEach((key, value) {
        processedMessage = processedMessage.replaceAll('[$key]', value);
      });
    }
    
    return processedMessage;
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  // Log SMS to Firestore for tracking
  Future<void> _logSMSToFirestore({
    required String phoneNumber,
    required String message,
    required String status,
    Map<String, dynamic>? response,
    String? error,
  }) async {
    try {
      await _firestore.collection('smsLogs').add({
        'phoneNumber': phoneNumber,
        'message': message,
        'status': status,
        'response': response,
        'error': error,
        'timestamp': FieldValue.serverTimestamp(),
        'apiKey': _apiKey.substring(0, 8) + '...', // Log partial key for tracking
      });
    } catch (e) {
      print('Failed to log SMS to Firestore: $e');
    }
  }

  // Get SMS logs for a building
  Future<List<Map<String, dynamic>>> getSMSLogs({int limit = 50}) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('smsLogs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Failed to get SMS logs: $e');
    }
  }
}