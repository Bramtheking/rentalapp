import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
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
  Map<String, TextEditingController> _dustbinControllers = {};
  final TextEditingController _defaultDustbinController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadUnits();
  }

  @override
  void dispose() {
    _waterControllers.values.forEach((controller) => controller.dispose());
    _electricityControllers.values.forEach((controller) => controller.dispose());
    _dustbinControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        setState(() {
          _userRole = userDoc.data()?['userType'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading user role: $e');
    }
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
      _dustbinControllers.clear();

      for (var unit in units) {
        // Check if bills already exist for this month
        double water = 0;
        double electricity = 0;
        double dustbin = unit.fixedBills['dustbin'] ?? 0;

        if (unit.currentBillsMonth != null) {
          final unitMonth = DateTime.parse(unit.currentBillsMonth!);
          if (unitMonth.year == _selectedMonth.year && unitMonth.month == _selectedMonth.month) {
            water = unit.currentMonthBills?['water'] ?? 0;
            electricity = unit.currentMonthBills?['electricity'] ?? 0;
            dustbin = unit.currentMonthBills?['dustbin'] ?? dustbin;
          }
        }

        _waterControllers[unit.unitNumber] = TextEditingController(
          text: water > 0 ? water.toStringAsFixed(0) : '',
        );
        _electricityControllers[unit.unitNumber] = TextEditingController(
          text: electricity > 0 ? electricity.toStringAsFixed(0) : '',
        );
        _dustbinControllers[unit.unitNumber] = TextEditingController(
          text: dustbin > 0 ? dustbin.toStringAsFixed(0) : '',
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
        final dustbinText = _dustbinControllers[unit.unitNumber]?.text.trim() ?? '';

        final water = waterText.isEmpty ? 0.0 : double.parse(waterText);
        final electricity = electricityText.isEmpty ? 0.0 : double.parse(electricityText);
        final dustbin = dustbinText.isEmpty ? 0.0 : double.parse(dustbinText);

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
            'dustbin': dustbin,
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

  Future<void> _exportToExcel() async {
    try {
      var excelFile = excel.Excel.createExcel();
      excel.Sheet sheetObject = excelFile['Monthly Bills'];
      
      // Add header
      sheetObject.appendRow([
        excel.TextCellValue('Unit'),
        excel.TextCellValue('Tenant'),
        excel.TextCellValue('Monthly Rent (KES)'),
        excel.TextCellValue('Water (KES)'),
        excel.TextCellValue('Electricity (KES)'),
        excel.TextCellValue('Dustbin (KES)'),
        excel.TextCellValue('Total (KES)'),
      ]);
      
      // Add data rows
      for (var unit in _units) {
        final waterText = _waterControllers[unit.unitNumber]?.text.trim() ?? '';
        final electricityText = _electricityControllers[unit.unitNumber]?.text.trim() ?? '';
        final dustbinText = _dustbinControllers[unit.unitNumber]?.text.trim() ?? '';
        final water = waterText.isEmpty ? 0.0 : double.parse(waterText);
        final electricity = electricityText.isEmpty ? 0.0 : double.parse(electricityText);
        final dustbin = dustbinText.isEmpty ? 0.0 : double.parse(dustbinText);
        final monthlyRent = unit.baseRent;
        final total = monthlyRent + water + electricity + dustbin;
        
        sheetObject.appendRow([
          excel.TextCellValue(unit.unitNumber),
          excel.TextCellValue(unit.tenantName ?? 'Vacant'),
          excel.DoubleCellValue(monthlyRent),
          excel.DoubleCellValue(water),
          excel.DoubleCellValue(electricity),
          excel.DoubleCellValue(dustbin),
          excel.DoubleCellValue(total),
        ]);
      }
      
      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'Monthly_Bills_${_getMonthName(_selectedMonth).replaceAll(' ', '_')}.xlsx';
      final filePath = '${directory.path}/$fileName';
      
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excelFile.encode()!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel exported to: $filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting to Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToPDF() async {
    try {
      final pdf = pw.Document();
      
      // Prepare data
      List<List<String>> tableData = [];
      tableData.add(['Unit', 'Tenant', 'Rent', 'Water', 'Electricity', 'Dustbin', 'Total']);
      
      for (var unit in _units) {
        final waterText = _waterControllers[unit.unitNumber]?.text.trim() ?? '';
        final electricityText = _electricityControllers[unit.unitNumber]?.text.trim() ?? '';
        final dustbinText = _dustbinControllers[unit.unitNumber]?.text.trim() ?? '';
        final water = waterText.isEmpty ? 0.0 : double.parse(waterText);
        final electricity = electricityText.isEmpty ? 0.0 : double.parse(electricityText);
        final dustbin = dustbinText.isEmpty ? 0.0 : double.parse(dustbinText);
        final monthlyRent = unit.baseRent;
        final total = monthlyRent + water + electricity + dustbin;
        
        tableData.add([
          unit.unitNumber,
          unit.tenantName ?? 'Vacant',
          monthlyRent.toStringAsFixed(0),
          water.toStringAsFixed(0),
          electricity.toStringAsFixed(0),
          dustbin.toStringAsFixed(0),
          total.toStringAsFixed(0),
        ]);
      }
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Monthly Bills Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  _getMonthName(_selectedMonth),
                  style: pw.TextStyle(fontSize: 18),
                ),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  data: tableData,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
              ],
            );
          },
        ),
      );
      
      // Save or share PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting to PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Export Bills',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Export to Excel'),
              subtitle: const Text('Download as .xlsx file'),
              onTap: () {
                Navigator.pop(context);
                _exportToExcel();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export to PDF'),
              subtitle: const Text('Generate PDF document'),
              onTap: () {
                Navigator.pop(context);
                _exportToPDF();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Monthly Bills'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _showExportOptions,
            tooltip: 'Export Bills',
          ),
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
                                          'Monthly Rent',
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
                                          'Total',
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
    final dustbinController = _dustbinControllers[unit.unitNumber]!;
    final monthlyRent = unit.baseRent;
    final isEditor = _userRole == 'editor';

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

          // Monthly Rent (Read-only for everyone)
          Expanded(
            flex: 2,
            child: Text(
              monthlyRent > 0 ? monthlyRent.toStringAsFixed(0) : '-',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Water Input (Editable for editors)
          Expanded(
            flex: 2,
            child: TextField(
              controller: waterController,
              enabled: !isEditor || isEditor, // Editors can edit
              decoration: InputDecoration(
                hintText: '0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                filled: isEditor,
                fillColor: isEditor ? Colors.blue[50] : null,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              onChanged: (_) => setState(() {}),
            ),
          ),

          const SizedBox(width: 8),

          // Electricity Input (Editable for editors)
          Expanded(
            flex: 2,
            child: TextField(
              controller: electricityController,
              enabled: !isEditor || isEditor, // Editors can edit
              decoration: InputDecoration(
                hintText: '0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                filled: isEditor,
                fillColor: isEditor ? Colors.blue[50] : null,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              onChanged: (_) => setState(() {}),
            ),
          ),

          const SizedBox(width: 8),

          // Dustbin Input (Editable - NOT fixed anymore)
          Expanded(
            flex: 2,
            child: TextField(
              controller: dustbinController,
              enabled: !isEditor, // Editors CANNOT edit dustbin
              decoration: InputDecoration(
                hintText: '0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                filled: isEditor,
                fillColor: isEditor ? Colors.grey[200] : null,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              onChanged: (_) => setState(() {}),
            ),
          ),

          const SizedBox(width: 8),

          // Total (Rent + Bills)
          Expanded(
            flex: 2,
            child: Text(
              _calculateTotal(monthlyRent, waterController.text, electricityController.text, dustbinController.text).toStringAsFixed(0),
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

  double _calculateTotal(double rent, String water, String electricity, String dustbin) {
    final waterAmount = water.isEmpty ? 0.0 : double.tryParse(water) ?? 0.0;
    final electricityAmount = electricity.isEmpty ? 0.0 : double.tryParse(electricity) ?? 0.0;
    final dustbinAmount = dustbin.isEmpty ? 0.0 : double.tryParse(dustbin) ?? 0.0;
    return rent + waterAmount + electricityAmount + dustbinAmount;
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
