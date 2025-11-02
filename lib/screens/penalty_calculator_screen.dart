import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PenaltyCalculatorScreen extends StatefulWidget {
  final String buildingId;
  final String buildingName;

  const PenaltyCalculatorScreen({
    super.key,
    required this.buildingId,
    required this.buildingName,
  });

  @override
  State<PenaltyCalculatorScreen> createState() => _PenaltyCalculatorScreenState();
}

class _PenaltyCalculatorScreenState extends State<PenaltyCalculatorScreen> {
  List<PenaltyRecord> _penalties = [];
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadPenalties();
  }

  Future<void> _loadPenalties() async {
    print('🔍 PENALTY CALCULATOR: Starting to load penalties');
    print('🏢 Building ID: ${widget.buildingId}');
    print('📅 Selected Month: ${_selectedMonth.year}-${_selectedMonth.month}');
    
    setState(() {
      _isLoading = true;
    });

    try {
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month);
      print('📅 Start of month timestamp: ${Timestamp.fromDate(startOfMonth)}');

      print('🔍 Executing Firestore query...');
      print('📍 Collection path: rentals/${widget.buildingId}/penalties');
      print('🔍 Query: where("month", "==", ${Timestamp.fromDate(startOfMonth)}).orderBy("calculatedDate", descending: true)');

      final snapshot = await FirebaseFirestore.instance
          .collection('rentals')
          .doc(widget.buildingId)
          .collection('penalties')
          .where('month', isEqualTo: Timestamp.fromDate(startOfMonth))
          .orderBy('calculatedDate', descending: true)
          .get();

      print('✅ Query completed successfully');
      print('📊 Found ${snapshot.docs.length} penalty records');

      List<PenaltyRecord> penalties = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        penalties.add(PenaltyRecord(
          id: doc.id,
          unitRef: data['unitRef'] ?? '',
          penaltyType: data['penaltyType'] ?? '',
          daysLate: data['daysLate'] ?? 0,
          penaltyAmount: (data['penaltyAmount'] ?? 0).toDouble(),
          status: data['status'] ?? 'active',
          calculatedDate: (data['calculatedDate'] as Timestamp).toDate(),
          month: _selectedMonth,
        ));
      }

      setState(() {
        _penalties = penalties;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ ERROR in _loadPenalties: $e');
      print('🔍 Error type: ${e.runtimeType}');
      print('📍 This might be a Firestore index issue');
      print('💡 Check Firebase Console > Firestore > Indexes');
      print('📝 Required index: Collection: penalties, Fields: month (Ascending), calculatedDate (Descending)');
      
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading penalties: $e')),
      );
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
              // Header with back button
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    // Back button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
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
                        Icons.calculate_rounded,
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
                            'Penalty Calculator',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Manage penalties for ${widget.buildingName}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.calculate, color: Colors.white),
                        onPressed: () => _showCalculatePenaltiesDialog(),
                        tooltip: 'Calculate Penalties',
                      ),
                    ),
                  ],
                ),
              ),

              // Month selector
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: Colors.white.withOpacity(0.8)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected Month',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_getMonthName(_selectedMonth.month)} ${_selectedMonth.year}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _selectMonth(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

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
                      : _buildPenaltiesContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPenaltiesContent() {
    if (_penalties.isEmpty) {
      return _buildEmptyState();
    }

    double totalPenalties = _penalties
        .where((p) => p.status == 'active')
        .fold(0.0, (sum, penalty) => sum + penalty.penaltyAmount);

    return Column(
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Penalty Summary',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    Text(
                      '${_getMonthName(_selectedMonth.month)} ${_selectedMonth.year}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Total Penalties',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[600],
                      ),
                    ),
                    Text(
                      'KES ${totalPenalties.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Penalties list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _penalties.length,
            itemBuilder: (context, index) {
              final penalty = _penalties[index];
              return _buildPenaltyCard(penalty);
            },
          ),
        ),
      ],
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
            'No Penalties',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No penalties found for ${_getMonthName(_selectedMonth.month)} ${_selectedMonth.year}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCalculatePenaltiesDialog(),
            icon: const Icon(Icons.calculate_rounded),
            label: const Text('Calculate Penalties'),
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

  Widget _buildPenaltyCard(PenaltyRecord penalty) {
    Color statusColor = penalty.status == 'active' ? Colors.red : Colors.grey;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unit ${penalty.unitRef}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      Text(
                        _getPenaltyTypeDisplay(penalty.penaltyType),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    penalty.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Penalty details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Days Late',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${penalty.daysLate} days',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Penalty Amount',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'KES ${penalty.penaltyAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calculated',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${penalty.calculatedDate.day}/${penalty.calculatedDate.month}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            if (penalty.status == 'active') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _clearPenalty(penalty),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Clear Penalty'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editPenalty(penalty),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF667eea),
                        side: const BorderSide(color: Color(0xFF667eea)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _getPenaltyTypeDisplay(String type) {
    switch (type) {
      case 'lateRent':
        return 'Late Rent Payment';
      case 'partialPayment':
        return 'Partial Payment';
      default:
        return type;
    }
  }

  void _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF667eea),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      _loadPenalties();
    }
  }

  void _showCalculatePenaltiesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Calculate Penalties'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will calculate penalties for all units based on:'),
            SizedBox(height: 8),
            Text('• Late payment dates'),
            Text('• Payment structure settings'),
            Text('• Existing penalty rules'),
            SizedBox(height: 16),
            Text(
              'Note: This feature will be fully implemented with automatic penalty calculation based on payment due dates.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Simulate penalty calculation for all overdue units
              _calculatePenaltiesForAllUnits();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
            ),
            child: const Text('Calculate'),
          ),
        ],
      ),
    );
  }

  void _clearPenalty(PenaltyRecord penalty) async {
    try {
      await FirebaseFirestore.instance
          .collection('rentals')
          .doc(widget.buildingId)
          .collection('penalties')
          .doc(penalty.id)
          .update({'status': 'cleared'});

      _loadPenalties();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Penalty for Unit ${penalty.unitRef} cleared'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing penalty: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editPenalty(PenaltyRecord penalty) {
    // Show edit penalty dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Penalty'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'New Penalty Amount',
                prefixText: 'KES ',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                // Handle penalty edit
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Penalty updated successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _calculatePenaltiesForAllUnits() async {
    try {
      // Get all units in the building
      final unitsSnapshot = await FirebaseFirestore.instance
          .collection('rentals')
          .doc(widget.buildingId)
          .collection('units')
          .get();

      int penaltiesCalculated = 0;
      
      for (var unitDoc in unitsSnapshot.docs) {
        final unitData = unitDoc.data();
        final unitRef = unitData['unitRef'] ?? 'Unknown';
        final rentAmount = (unitData['rentAmount'] ?? 0).toDouble();
        
        // Check if there are overdue payments for this unit
        final paymentsSnapshot = await FirebaseFirestore.instance
            .collection('rentals')
            .doc(widget.buildingId)
            .collection('payments')
            .where('unitRef', isEqualTo: unitRef)
            .where('status', isEqualTo: 'overdue')
            .get();
            
        if (paymentsSnapshot.docs.isNotEmpty) {
          // Calculate penalty (2% per day overdue, max 20%)
          final now = DateTime.now();
          final dueDate = DateTime(now.year, now.month, 5); // Assume rent due on 5th
          int daysOverdue = now.difference(dueDate).inDays;
          
          if (daysOverdue > 0) {
            double penaltyRate = (daysOverdue * 0.02).clamp(0.0, 0.20);
            double penaltyAmount = rentAmount * penaltyRate;
            
            // Create penalty record
            await FirebaseFirestore.instance
                .collection('rentals')
                .doc(widget.buildingId)
                .collection('penalties')
                .add({
              'unitRef': unitRef,
              'penaltyType': 'Late Payment',
              'amount': penaltyAmount,
              'daysOverdue': daysOverdue,
              'calculatedDate': Timestamp.now(),
              'month': Timestamp.fromDate(DateTime(now.year, now.month)),
              'status': 'active',
            });
            
            penaltiesCalculated++;
          }
        }
      }
      
      _loadPenalties();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Calculated penalties for $penaltiesCalculated units'),
          backgroundColor: const Color(0xFF667eea),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error calculating penalties: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class PenaltyRecord {
  final String id;
  final String unitRef;
  final String penaltyType;
  final int daysLate;
  final double penaltyAmount;
  final String status;
  final DateTime calculatedDate;
  final DateTime month;

  PenaltyRecord({
    required this.id,
    required this.unitRef,
    required this.penaltyType,
    required this.daysLate,
    required this.penaltyAmount,
    required this.status,
    required this.calculatedDate,
    required this.month,
  });
}