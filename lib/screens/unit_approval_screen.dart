import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/sms_service.dart';
import '../models/sms_format_model.dart';

class UnitApprovalScreen extends StatefulWidget {
  final String buildingId;
  final String buildingName;

  const UnitApprovalScreen({
    super.key,
    required this.buildingId,
    required this.buildingName,
  });

  @override
  State<UnitApprovalScreen> createState() => _UnitApprovalScreenState();
}

class _UnitApprovalScreenState extends State<UnitApprovalScreen> {
  List<PendingUnit> _pendingUnits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingUnits();
  }

  Future<void> _loadPendingUnits() async {
    try {
      // Get pending units from SMS transactions that don't match existing units
      final smsTransactions = await SMSService().getSMSTransactions(widget.buildingId);
      
      // Get existing units from the building
      final existingUnits = await _getExistingUnits();
      
      // Find units in SMS that don't exist in the system
      Set<String> pendingUnitRefs = {};
      Map<String, SMSTransaction> unitTransactions = {};
      
      for (var transaction in smsTransactions) {
        if (transaction.unit.isNotEmpty && !existingUnits.contains(transaction.unit)) {
          pendingUnitRefs.add(transaction.unit);
          // Keep the latest transaction for each unit
          if (!unitTransactions.containsKey(transaction.unit) ||
              transaction.date.isAfter(unitTransactions[transaction.unit]!.date)) {
            unitTransactions[transaction.unit] = transaction;
          }
        }
      }
      
      // Create pending unit objects
      List<PendingUnit> pendingUnits = [];
      for (String unitRef in pendingUnitRefs) {
        final transaction = unitTransactions[unitRef]!;
        pendingUnits.add(PendingUnit(
          unitRef: unitRef,
          buildingRef: transaction.building,
          amount: transaction.amount,
          lastSMSDate: transaction.date,
          transactionCount: smsTransactions.where((t) => t.unit == unitRef).length,
          sampleTransaction: transaction,
        ));
      }
      
      setState(() {
        _pendingUnits = pendingUnits;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading pending units: $e')),
      );
    }
  }

  Future<Set<String>> _getExistingUnits() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rentals')
          .doc(widget.buildingId)
          .collection('units')
          .get();
      
      return snapshot.docs.map((doc) => doc.data()['unitNumber'] as String).toSet();
    } catch (e) {
      return <String>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFFf093fb),
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.approval_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Unit Approval',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Approve new units found in SMS for ${widget.buildingName}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_pendingUnits.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '${_pendingUnits.length} pending',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                          ),
                        )
                      : _pendingUnits.isEmpty
                          ? _buildEmptyState()
                          : _buildPendingUnitsList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green[400],
          ),
          const SizedBox(height: 16),
          Text(
            'All Units Approved!',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No new units found in SMS messages that need approval',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _loadPendingUnits(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingUnitsList() {
    return Column(
      children: [
        // Header info
        Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Text(
                'Units Found in SMS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const Spacer(),
              if (_pendingUnits.isNotEmpty)
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _approveAllUnits(),
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      label: const Text('Approve All', style: TextStyle(color: Colors.green)),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _rejectAllUnits(),
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      label: const Text('Reject All', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
            ],
          ),
        ),
        
        // Units list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _pendingUnits.length,
            itemBuilder: (context, index) {
              final unit = _pendingUnits[index];
              return _buildPendingUnitCard(unit);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPendingUnitCard(PendingUnit unit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.home_work_rounded,
                    color: Colors.orange[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unit ${unit.unitRef}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      Text(
                        'Building: ${unit.buildingRef}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PENDING',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[600],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Unit details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem('Last Payment', 'KES ${unit.amount.toStringAsFixed(0)}'),
                      ),
                      Expanded(
                        child: _buildDetailItem('SMS Count', '${unit.transactionCount} messages'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailItem('Last SMS Date', '${unit.lastSMSDate.day}/${unit.lastSMSDate.month}/${unit.lastSMSDate.year}'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Sample SMS
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF667eea).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sample SMS:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF667eea),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unit.sampleTransaction.rawSMS,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Color(0xFF2D3748),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveUnit(unit),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Approve & Create Unit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectUnit(unit),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
      ],
    );
  }

  void _approveUnit(PendingUnit unit) async {
    try {
      // Create the unit in Firestore
      await FirebaseFirestore.instance
          .collection('rentals')
          .doc(widget.buildingId)
          .collection('units')
          .add({
        'unitNumber': unit.unitRef,
        'rent': unit.amount,
        'isOccupied': true, // Assume occupied since we have payment SMS
        'tenantName': 'Unknown', // Will be updated when tenant is assigned
        'createdAt': FieldValue.serverTimestamp(),
        'createdFrom': 'sms_approval',
        'lastPaymentAmount': unit.amount,
        'lastPaymentDate': unit.lastSMSDate,
      });

      // Update SMS transactions to mark them as matched
      final smsService = SMSService();
      final transactions = await smsService.getSMSTransactions(widget.buildingId);
      
      for (var transaction in transactions) {
        if (transaction.unit == unit.unitRef && transaction.status == 'pending') {
          // Update transaction status to matched
          await FirebaseFirestore.instance
              .collection('rentals')
              .doc(widget.buildingId)
              .collection('smsTransactions')
              .doc(transaction.id)
              .update({'status': 'matched'});
        }
      }

      // Remove from pending list
      setState(() {
        _pendingUnits.remove(unit);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unit ${unit.unitRef} approved and created successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving unit: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  void _rejectUnit(PendingUnit unit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Unit'),
        content: Text('Are you sure you want to reject unit "${unit.unitRef}"? SMS messages for this unit will remain unmatched.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _pendingUnits.remove(unit);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Unit ${unit.unitRef} rejected'),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              );
            },
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _approveAllUnits() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve All Units'),
        content: Text('Are you sure you want to approve and create all ${_pendingUnits.length} units?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              
              // Show progress dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                      ),
                      const SizedBox(height: 16),
                      Text('Approving ${_pendingUnits.length} units...'),
                    ],
                  ),
                ),
              );

              int approvedCount = 0;
              for (var unit in List.from(_pendingUnits)) {
                try {
                  await _approveUnitSilently(unit);
                  approvedCount++;
                } catch (e) {
                  print('Error approving unit ${unit.unitRef}: $e');
                }
              }

              Navigator.pop(context); // Close progress dialog
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Successfully approved $approvedCount units!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              );
            },
            child: const Text('Approve All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _rejectAllUnits() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject All Units'),
        content: Text('Are you sure you want to reject all ${_pendingUnits.length} units?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _pendingUnits.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All units rejected'),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Reject All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _approveUnitSilently(PendingUnit unit) async {
    // Create the unit in Firestore
    await FirebaseFirestore.instance
        .collection('rentals')
        .doc(widget.buildingId)
        .collection('units')
        .add({
      'unitNumber': unit.unitRef,
      'rent': unit.amount,
      'isOccupied': true,
      'tenantName': 'Unknown',
      'createdAt': FieldValue.serverTimestamp(),
      'createdFrom': 'sms_approval',
      'lastPaymentAmount': unit.amount,
      'lastPaymentDate': unit.lastSMSDate,
    });

    // Update SMS transactions
    final smsService = SMSService();
    final transactions = await smsService.getSMSTransactions(widget.buildingId);
    
    for (var transaction in transactions) {
      if (transaction.unit == unit.unitRef && transaction.status == 'pending') {
        await FirebaseFirestore.instance
            .collection('rentals')
            .doc(widget.buildingId)
            .collection('smsTransactions')
            .doc(transaction.id)
            .update({'status': 'matched'});
      }
    }

    // Remove from pending list
    setState(() {
      _pendingUnits.remove(unit);
    });
  }
}

class PendingUnit {
  final String unitRef;
  final String buildingRef;
  final double amount;
  final DateTime lastSMSDate;
  final int transactionCount;
  final SMSTransaction sampleTransaction;

  PendingUnit({
    required this.unitRef,
    required this.buildingRef,
    required this.amount,
    required this.lastSMSDate,
    required this.transactionCount,
    required this.sampleTransaction,
  });
}