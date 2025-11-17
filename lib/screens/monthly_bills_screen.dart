import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/unit_model.dart';
import '../models/monthly_bills_model.dart';

class MonthlyBillsScreen extends StatefulWidget {
  final String rentalId;

  const MonthlyBillsScreen({
    super.key,
    required this.rentalId,
  });

  @override
  State<MonthlyBillsScreen> createState() => _MonthlyBillsScreenState();
}

class _MonthlyBillsScreenState extends State<MonthlyBillsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<Unit> _units = [];
  Map<String, TextEditingController> _waterControllers = {};
  Map<String, TextEditingController> _electricityControllers = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  @override
  void dispose() {
    _waterControllers.values.forEach((controller) => controller.dispose());
    _electricityControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadUnits() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore
          .collection('rentals')
          .doc(widget.rentalId)
          .collection('units')
          .orderBy('unitNumber')
          .get();

      final units = snapshot.docs.map((doc) => Unit.fromFirestore(doc)).toList();

      // Initialize controllers
      _waterControllers.clear();
      _electricityControllers.clear();

      for (var unit in units) {
        // Check if bills already exist for this month
        double water = 0;
        double electricity = 0;

        if (unit.currentBillsMonth != null) {
          final unitMonth = DateTime.parse(unit.currentBillsMonth!);
          if (unitMonth.year == _selectedMonth.year && unitMonth.month == _selectedMonth.month) {
            water = unit.currentMonthBills?['water'] ?? 0;
            electricity = unit.currentMonthBills?['electricity'] ?? 0;
          }
        }

        _waterControllers[unit.unitNumber] = TextEditingController(
          text: water > 0 ? water.toStringAsFixed(0) : '',
        );
        _electricityControllers[unit.unitNumber] = TextEditingController(
          text: electricity > 0 ? electricity.toStringAsFixed(0) : '',
        );
      }

      setState(() {
        _units = units;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading units: $e')),
        );
      }
    }
  }

  Future<void> _saveBills() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Prepare bills data
      Map<String, UnitBills> billsMap = {};
      for (var unit in _units) {
        final waterText = _waterControllers[unit.unitNumber]?.text.trim() ?? '';
        final electricityText = _electricityControllers[unit.unitNumber]?.text.trim() ?? '';

        final water = waterText.isEmpty ? 0.0 : double.parse(waterText);
        final electricity = electricityText.isEmpty ? 0.0 : double.parse(electricityText);

        billsMap[unit.unitNumber] = UnitBills(
          water: water,
          electricity: electricity,
        );

        // Update unit's current month bills
        await _firestore
            .collection('rentals')
            .doc(widget.rentalId)
            .collection('units')
            .doc(unit.id)
            .update({
          'currentMonthBills': {
            'water': water,
            'electricity': electricity,
          },
          'currentBillsMonth': _selectedMonth.toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Save monthly bills record
      final monthlyBills = MonthlyBills(
        id: '',
        buildingId: widget.rentalId,
        month: _selectedMonth,
        bills: billsMap,
        enteredDate: DateTime.now(),
        enteredBy: user.uid,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('rentals')
          .doc(widget.rentalId)
          .collection('monthly_bills')
          .add(monthlyBills.toFirestore());

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bills saved for ${_getMonthName(_selectedMonth)}!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving bills: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getMonthName(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Monthly Bills'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Month Selector
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Color(0xFF667eea)),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Month:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<DateTime>(
                              value: _selectedMonth,
                              isExpanded: true,
                              items: _generateMonthOptions(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedMonth = value;
                                  });
                                  _loadUnits();
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bills Table
                Expanded(
                  child: _units.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.home_work_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No units found',
                                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Table Header
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF667eea),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      topRight: Radius.circular(12),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Unit',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Tenant',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Water (KES)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Electricity (KES)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Dustbin (Fixed)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Total Bills',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Table Rows
                                ..._units.map((unit) => _buildUnitRow(unit)).toList(),
                              ],
                            ),
                          ),
                        ),
                ),

                // Save Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveBills,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isSaving ? 'Saving...' : 'Save Bills for ${_getMonthName(_selectedMonth)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUnitRow(Unit unit) {
    final waterController = _waterControllers[unit.unitNumber]!;
    final electricityController = _electricityControllers[unit.unitNumber]!;
    final dustbin = unit.fixedBills['dustbin'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          // Unit Number
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.unitNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  unit.status,
                  style: TextStyle(
                    fontSize: 12,
                    color: unit.status == 'occupied' ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Tenant Name
          Expanded(
            flex: 2,
            child: Text(
              unit.tenantName ?? 'Vacant',
              style: TextStyle(
                fontSize: 13,
                color: unit.tenantName != null ? Colors.black87 : Colors.grey,
              ),
            ),
          ),

          // Water Input
          Expanded(
            flex: 2,
            child: TextField(
              controller: waterController,
              decoration: InputDecoration(
                hintText: '0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              onChanged: (_) => setState(() {}),
            ),
          ),

          const SizedBox(width: 8),

          // Electricity Input
          Expanded(
            flex: 2,
            child: TextField(
              controller: electricityController,
              decoration: InputDecoration(
                hintText: '0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              onChanged: (_) => setState(() {}),
            ),
          ),

          const SizedBox(width: 8),

          // Dustbin (Fixed)
          Expanded(
            flex: 2,
            child: Text(
              dustbin > 0 ? dustbin.toStringAsFixed(0) : '-',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Total
          Expanded(
            flex: 2,
            child: Text(
              _calculateTotal(waterController.text, electricityController.text, dustbin).toStringAsFixed(0),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF667eea),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotal(String water, String electricity, double dustbin) {
    final waterAmount = water.isEmpty ? 0.0 : double.tryParse(water) ?? 0.0;
    final electricityAmount = electricity.isEmpty ? 0.0 : double.tryParse(electricity) ?? 0.0;
    return waterAmount + electricityAmount + dustbin;
  }

  List<DropdownMenuItem<DateTime>> _generateMonthOptions() {
    List<DropdownMenuItem<DateTime>> items = [];
    final now = DateTime.now();

    // Generate options for current month and next 11 months (1 year ahead)
    for (int i = 0; i < 12; i++) {
      final month = DateTime(now.year, now.month + i, 1);
      items.add(
        DropdownMenuItem(
          value: month,
          child: Text(_getMonthName(month)),
        ),
      );
    }

    return items;
  }
}
