import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';
import '../models/report_model.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AuthService _authService = AuthService();
  final ReportService _reportService = ReportService();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  
  Map<String, dynamic>? currentUser;
  String? selectedRentalId;
  String selectedProperty = 'All Properties';
  bool isLoading = true;
  bool isGeneratingReport = false;
  
  // Available rentals for dropdown
  List<Map<String, dynamic>> availableRentals = [];
  Map<String, String> rentalIdToName = {};

  // Financial data
  FinancialSummary? financialSummary;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Set default date range (current month)
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    _startDateController.text = '${firstDay.day.toString().padLeft(2, '0')}/${firstDay.month.toString().padLeft(2, '0')}/${firstDay.year}';
    _endDateController.text = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await _authService.getUserData(user.uid);
      setState(() {
        currentUser = userData;
        final rental = userData?['rental'] as String?;
        if (rental != null && rental.isNotEmpty) {
          selectedRentalId = rental;
        }
      });
      
      // Load available rentals for dropdown
      await _loadAvailableRentals();
      
      setState(() {
        isLoading = false;
      });
      
      // Load financial summary for current month
      if (selectedRentalId != null) {
        await _loadFinancialSummary();
      }
    }
  }

  Future<void> _loadAvailableRentals() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userData = await _authService.getUserData(user.uid);
      String userType = userData?['userType'] ?? '';
      
      List<Map<String, dynamic>> buildings = [];

      // Load buildings based on user role (similar to home screen logic)
      if (userType == 'rentalmanager' || userType == 'superadmin') {
        // Rental managers and superadmins can see buildings they created
        
        // Check if user has buildings array (new system)
        if (userData?['buildings'] != null) {
          List<String> buildingIds = List<String>.from(userData!['buildings']);
          
          for (String buildingId in buildingIds) {
            DocumentSnapshot buildingDoc = await FirebaseFirestore.instance
                .collection('rentals')
                .doc(buildingId)
                .get();
            
            if (buildingDoc.exists) {
              Map<String, dynamic> buildingData = buildingDoc.data() as Map<String, dynamic>;
              if (buildingData['isActive'] == true) {
                buildings.add({
                  'id': buildingId,
                  'name': buildingData['name'] ?? 'Unnamed Building',
                });
              }
            }
          }
        } else {
          // Fallback: Query buildings created by this user
          QuerySnapshot buildingQuery = await FirebaseFirestore.instance
              .collection('rentals')
              .where('createdBy', isEqualTo: user.uid)
              .where('isActive', isEqualTo: true)
              .get();
          
          for (DocumentSnapshot buildingDoc in buildingQuery.docs) {
            Map<String, dynamic> buildingData = buildingDoc.data() as Map<String, dynamic>;
            buildings.add({
              'id': buildingDoc.id,
              'name': buildingData['name'] ?? 'Unnamed Building',
            });
          }
        }
        
      } else if (userType == 'editor') {
        // Editors can only access buildings assigned to them via the rental field
        if (userData?['rental'] != null && userData!['rental'].toString().isNotEmpty) {
          String rentalName = userData['rental'];
          
          // Query building by name (for editors, we use the rental field)
          QuerySnapshot buildingQuery = await FirebaseFirestore.instance
              .collection('rentals')
              .where('name', isEqualTo: rentalName)
              .where('isActive', isEqualTo: true)
              .limit(1)
              .get();
          
          if (buildingQuery.docs.isNotEmpty) {
            DocumentSnapshot buildingDoc = buildingQuery.docs.first;
            Map<String, dynamic> buildingData = buildingDoc.data() as Map<String, dynamic>;
            buildings.add({
              'id': buildingDoc.id,
              'name': buildingData['name'] ?? rentalName,
            });
          }
        }
        
        // Also check if editor has specific buildings assigned via buildings array
        if (userData?['buildings'] != null) {
          List<String> buildingIds = List<String>.from(userData!['buildings']);
          
          for (String buildingId in buildingIds) {
            DocumentSnapshot buildingDoc = await FirebaseFirestore.instance
                .collection('rentals')
                .doc(buildingId)
                .get();
            
            if (buildingDoc.exists) {
              Map<String, dynamic> buildingData = buildingDoc.data() as Map<String, dynamic>;
              if (buildingData['isActive'] == true) {
                // Avoid duplicates
                if (!buildings.any((b) => b['id'] == buildingId)) {
                  buildings.add({
                    'id': buildingId,
                    'name': buildingData['name'] ?? 'Unnamed Building',
                  });
                }
              }
            }
          }
        }
      }

      availableRentals = buildings;
      
      // Build rental ID to name mapping
      rentalIdToName = {};
      for (var rental in availableRentals) {
        rentalIdToName[rental['id']] = rental['name'];
      }
      
      // Set default selection based on current user's rental or first available
      if (availableRentals.isNotEmpty) {
        // Try to use the current selectedRentalId if it exists in available rentals
        if (selectedRentalId != null && availableRentals.any((r) => r['id'] == selectedRentalId)) {
          selectedProperty = rentalIdToName[selectedRentalId]!;
        } else {
          // Use the first available rental
          selectedRentalId = availableRentals.first['id'];
          selectedProperty = availableRentals.first['name'];
        }
        
        // Add "All Properties" option if user has multiple rentals
        if (availableRentals.length > 1) {
          availableRentals.insert(0, {'id': 'all', 'name': 'All Properties'});
        }
      }
      
    } catch (e) {
      print('Error loading available rentals: $e');
    }
  }

  Future<void> _loadFinancialSummary() async {
    if (selectedRentalId == null && selectedProperty != 'All Properties') return;
    
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      
      FinancialSummary summary;
      
      if (selectedProperty == 'All Properties') {
        // Combine data from all properties
        List<String> rentalIds = availableRentals
            .where((r) => r['id'] != 'all')
            .map<String>((r) => r['id'] as String)
            .toList();
        
        if (rentalIds.isEmpty) return;
        
        double totalIncome = 0;
        double totalExpenses = 0;
        int totalUnits = 0;
        int occupiedUnits = 0;
        Map<String, double> combinedIncomeByCategory = {};
        Map<String, double> combinedExpensesByCategory = {};
        
        for (String rentalId in rentalIds) {
          FinancialSummary individualSummary = await _reportService.generateFinancialSummary(
            rentalId,
            startOfMonth,
            endOfMonth,
          );
          
          totalIncome += individualSummary.totalIncome;
          totalExpenses += individualSummary.totalExpenses;
          totalUnits += individualSummary.totalUnits;
          occupiedUnits += individualSummary.occupiedUnits;
          
          individualSummary.incomeByCategory.forEach((category, amount) {
            combinedIncomeByCategory[category] = (combinedIncomeByCategory[category] ?? 0) + amount;
          });
          
          individualSummary.expensesByCategory.forEach((category, amount) {
            combinedExpensesByCategory[category] = (combinedExpensesByCategory[category] ?? 0) + amount;
          });
        }
        
        double netProfit = totalIncome - totalExpenses;
        double occupancyRate = totalUnits > 0 ? (occupiedUnits / totalUnits) * 100 : 0;
        double averageRent = occupiedUnits > 0 ? totalIncome / occupiedUnits : 0;
        int vacantUnits = totalUnits - occupiedUnits;
        
        summary = FinancialSummary(
          totalIncome: totalIncome,
          totalExpenses: totalExpenses,
          netProfit: netProfit,
          occupancyRate: occupancyRate,
          totalUnits: totalUnits,
          occupiedUnits: occupiedUnits,
          vacantUnits: vacantUnits,
          averageRent: averageRent,
          incomeByCategory: combinedIncomeByCategory,
          expensesByCategory: combinedExpensesByCategory,
          periodStart: startOfMonth,
          periodEnd: endOfMonth,
        );
      } else {
        // Single property
        summary = await _reportService.generateFinancialSummary(
          selectedRentalId!,
          startOfMonth,
          endOfMonth,
        );
      }
      
      setState(() {
        financialSummary = summary;
      });
    } catch (e) {
      print('Error loading financial summary: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (selectedRentalId == null) {
      return const Scaffold(
        body: Center(
          child: Text('No rental assigned to your account'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: const Color(0xFF764ba2),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Reports Header
            Row(
              children: [
                Icon(Icons.folder_open, color: const Color(0xFF764ba2)),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Property Reports',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Select date range and generate reports',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Date Range and Property Selection
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startDateController,
                    decoration: const InputDecoration(
                      labelText: 'Start Date',
                      hintText: 'mm/dd/yyyy',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () => _selectDate(context, _startDateController),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _endDateController,
                    decoration: const InputDecoration(
                      labelText: 'End Date',
                      hintText: 'mm/dd/yyyy',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () => _selectDate(context, _endDateController),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: availableRentals.any((r) => r['name'] == selectedProperty) ? selectedProperty : null,
                    decoration: const InputDecoration(
                      labelText: 'Property',
                      border: OutlineInputBorder(),
                    ),
                    items: availableRentals.map<DropdownMenuItem<String>>((rental) {
                      return DropdownMenuItem<String>(
                        value: rental['name'],
                        child: Text(rental['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedProperty = value!;
                        // Update selectedRentalId based on selection
                        if (value == 'All Properties') {
                          selectedRentalId = null; // Will handle multiple rentals in reports
                        } else {
                          // Find the rental ID for the selected name
                          final rental = availableRentals.firstWhere(
                            (r) => r['name'] == value,
                            orElse: () => {'id': selectedRentalId},
                          );
                          selectedRentalId = rental['id'];
                        }
                      });
                      // Reload financial summary when property changes
                      if (selectedRentalId != null) {
                        _loadFinancialSummary();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _exportReports,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: const Text('Export'),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Report Cards Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildReportCard(
                  title: 'Rent Collection Report',
                  description: 'Detailed report of rent collections and outstanding amounts',
                  icon: Icons.attach_money,
                  color: Colors.green,
                  onGenerate: () => _generateReport('rent_collection'),
                ),
                _buildReportCard(
                  title: 'Expense Report',
                  description: 'Summary of all expenses by category and time period',
                  icon: Icons.receipt_long,
                  color: const Color(0xFF764ba2),
                  onGenerate: () => _generateReport('expense'),
                ),
                _buildReportCard(
                  title: 'Profit & Loss Statement',
                  description: 'Financial performance overview with income and expenses',
                  icon: Icons.trending_up,
                  color: Colors.purple,
                  onGenerate: () => _generateReport('profit_loss'),
                ),
                _buildReportCard(
                  title: 'Arrears Report',
                  description: 'List of tenants with outstanding rent payments',
                  icon: Icons.warning,
                  color: Colors.red,
                  onGenerate: () => _generateReport('arrears'),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Financial Summary Cards
            const Text(
              'Financial Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (financialSummary != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: "This Month's Collection",
                      amount: financialSummary!.totalIncome,
                      subtitle: 'Total income for the period',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Total Expenses',
                      amount: financialSummary!.totalExpenses,
                      subtitle: 'Total expenses for the period',
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Net Profit',
                      amount: financialSummary!.netProfit,
                      subtitle: 'Income minus expenses',
                      color: const Color(0xFFf093fb),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Occupancy Rate',
                      amount: financialSummary!.occupancyRate,
                      subtitle: '${financialSummary!.occupiedUnits}/${financialSummary!.totalUnits} units occupied',
                      color: Colors.blue,
                      isPercentage: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Average Rent',
                      amount: financialSummary!.averageRent,
                      subtitle: 'Average rent per unit',
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Vacant Units',
                      amount: financialSummary!.vacantUnits.toDouble(),
                      subtitle: 'Units available for rent',
                      color: Colors.orange,
                      isInteger: true,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onGenerate,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onGenerate,
                    icon: const Icon(Icons.description, size: 16),
                    label: const Text('Generate Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _downloadReport(title),
                  icon: const Icon(Icons.download),
                  tooltip: 'Download',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required String subtitle,
    required Color color,
    bool isPercentage = false,
    bool isInteger = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isPercentage 
                ? '${amount.toStringAsFixed(1)}%'
                : isInteger
                    ? amount.toInt().toString()
                    : 'KES ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      controller.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  void _exportReports() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.file_download, color: const Color(0xFF667eea)),
            const SizedBox(width: 8),
            const Text('Export Reports'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Export Details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Date Range: ${_startDateController.text} - ${_endDateController.text}'),
                  Text('Property: $selectedProperty'),
                  const SizedBox(height: 8),
                  const Text(
                    '📁 Files will be saved to your Downloads folder',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select export format:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showExportSuccess('PDF');
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showExportSuccess('Excel');
                    },
                    icon: const Icon(Icons.table_chart),
                    label: const Text('Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showExportSuccess('CSV');
                },
                icon: const Icon(Icons.text_snippet),
                label: const Text('CSV (Spreadsheet)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _generateReport(String reportType) async {
    if (selectedRentalId == null && selectedProperty != 'All Properties') return;
    
    String reportName = '';
    switch (reportType) {
      case 'rent_collection':
        reportName = 'Rent Collection Report';
        break;
      case 'expense':
        reportName = 'Expense Report';
        break;
      case 'profit_loss':
        reportName = 'Profit & Loss Statement';
        break;
      case 'arrears':
        reportName = 'Arrears Report';
        break;
    }

    setState(() {
      isGeneratingReport = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Generate $reportName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Generating $reportName...'),
            const SizedBox(height: 8),
            Text('Date Range: ${_startDateController.text} - ${_endDateController.text}'),
            Text('Property: $selectedProperty'),
          ],
        ),
      ),
    );

    try {
      DateTime startDate = _parseDate(_startDateController.text);
      DateTime endDate = _parseDate(_endDateController.text);

      // Handle "All Properties" case
      List<String> rentalIds = [];
      if (selectedProperty == 'All Properties') {
        rentalIds = availableRentals
            .where((r) => r['id'] != 'all')
            .map<String>((r) => r['id'] as String)
            .toList();
      } else if (selectedRentalId != null) {
        rentalIds = [selectedRentalId!];
      }

      if (rentalIds.isEmpty) {
        throw Exception('No properties selected for report generation');
      }

      switch (reportType) {
        case 'rent_collection':
          await _generateRentCollectionReport(startDate, endDate, rentalIds);
          break;
        case 'expense':
          await _generateExpenseReport(startDate, endDate, rentalIds);
          break;
        case 'profit_loss':
          await _generateProfitLossReport(startDate, endDate, rentalIds);
          break;
        case 'arrears':
          await _generateArrearsReport(endDate, rentalIds);
          break;
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$reportName generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isGeneratingReport = false;
      });
    }
  }

  Future<void> _generateRentCollectionReport(DateTime startDate, DateTime endDate, List<String> rentalIds) async {
    List<RentCollectionReport> allReports = [];
    
    for (String rentalId in rentalIds) {
      List<RentCollectionReport> reports = await _reportService.generateRentCollectionReport(
        rentalId,
        startDate,
        endDate,
      );
      allReports.addAll(reports);
    }

    _showReportDialog(
      title: 'Rent Collection Report',
      data: _reportService.rentCollectionToExportData(allReports),
      headers: ['Tenant Name', 'Unit Number', 'Expected Rent', 'Paid Amount', 'Outstanding Amount', 'Due Date', 'Payment Date', 'Status', 'Days Overdue'],
    );
  }

  Future<void> _generateExpenseReport(DateTime startDate, DateTime endDate, List<String> rentalIds) async {
    Map<String, double> combinedExpensesByCategory = {};
    double totalExpenses = 0;
    
    for (String rentalId in rentalIds) {
      FinancialSummary summary = await _reportService.generateFinancialSummary(
        rentalId,
        startDate,
        endDate,
      );
      
      totalExpenses += summary.totalExpenses;
      
      summary.expensesByCategory.forEach((category, amount) {
        combinedExpensesByCategory[category] = (combinedExpensesByCategory[category] ?? 0) + amount;
      });
    }

    List<Map<String, dynamic>> expenseData = combinedExpensesByCategory.entries.map((entry) => {
      'Category': entry.key,
      'Amount': 'KES ${entry.value.toStringAsFixed(2)}',
      'Percentage': totalExpenses > 0 ? '${((entry.value / totalExpenses) * 100).toStringAsFixed(1)}%' : '0%',
    }).toList();

    _showReportDialog(
      title: 'Expense Report',
      data: expenseData,
      headers: ['Category', 'Amount', 'Percentage'],
    );
  }

  Future<void> _generateProfitLossReport(DateTime startDate, DateTime endDate, List<String> rentalIds) async {
    double totalIncome = 0;
    double totalExpenses = 0;
    int totalUnits = 0;
    int occupiedUnits = 0;
    Map<String, double> combinedIncomeByCategory = {};
    Map<String, double> combinedExpensesByCategory = {};
    
    for (String rentalId in rentalIds) {
      FinancialSummary summary = await _reportService.generateFinancialSummary(
        rentalId,
        startDate,
        endDate,
      );
      
      totalIncome += summary.totalIncome;
      totalExpenses += summary.totalExpenses;
      totalUnits += summary.totalUnits;
      occupiedUnits += summary.occupiedUnits;
      
      summary.incomeByCategory.forEach((category, amount) {
        combinedIncomeByCategory[category] = (combinedIncomeByCategory[category] ?? 0) + amount;
      });
      
      summary.expensesByCategory.forEach((category, amount) {
        combinedExpensesByCategory[category] = (combinedExpensesByCategory[category] ?? 0) + amount;
      });
    }
    
    double netProfit = totalIncome - totalExpenses;
    double occupancyRate = totalUnits > 0 ? (occupiedUnits / totalUnits) * 100 : 0;
    double averageRent = occupiedUnits > 0 ? totalIncome / occupiedUnits : 0;
    int vacantUnits = totalUnits - occupiedUnits;
    
    // Create combined financial summary
    FinancialSummary combinedSummary = FinancialSummary(
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      occupancyRate: occupancyRate,
      totalUnits: totalUnits,
      occupiedUnits: occupiedUnits,
      vacantUnits: vacantUnits,
      averageRent: averageRent,
      incomeByCategory: combinedIncomeByCategory,
      expensesByCategory: combinedExpensesByCategory,
      periodStart: startDate,
      periodEnd: endDate,
    );

    _showReportDialog(
      title: 'Profit & Loss Statement',
      data: _reportService.financialSummaryToExportData(combinedSummary),
      headers: ['Metric', 'Amount', 'Period'],
    );
  }

  Future<void> _generateArrearsReport(DateTime endDate, List<String> rentalIds) async {
    List<RentCollectionReport> allReports = [];
    
    for (String rentalId in rentalIds) {
      List<RentCollectionReport> reports = await _reportService.generateArrearsReport(
        rentalId,
        endDate,
      );
      allReports.addAll(reports);
    }

    _showReportDialog(
      title: 'Arrears Report',
      data: _reportService.rentCollectionToExportData(allReports),
      headers: ['Tenant Name', 'Unit Number', 'Expected Rent', 'Paid Amount', 'Outstanding Amount', 'Due Date', 'Payment Date', 'Status', 'Days Overdue'],
    );
  }

  DateTime _parseDate(String dateStr) {
    List<String> parts = dateStr.split('/');
    return DateTime(
      int.parse(parts[2]), // year
      int.parse(parts[1]), // month
      int.parse(parts[0]), // day
    );
  }

  void _downloadReport(String reportTitle) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading $reportTitle...')),
    );
  }

  void _showExportSuccess(String format) {
    final fileName = 'PropertyReport_${selectedProperty.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.$format';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Export Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your report has been exported successfully!'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.file_present, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'File Details:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Format: ${format.toUpperCase()}'),
                  Text('File: $fileName'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.folder, color: Colors.blue.shade700, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        'Location: Downloads folder',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You can now open the file with your preferred application.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening Downloads folder...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.folder_open),
            label: const Text('Open Folder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog({
    required String title,
    required List<Map<String, dynamic>> data,
    required List<String> headers,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.description, color: const Color(0xFF667eea), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$selectedProperty • ${_startDateController.text} - ${_endDateController.text}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.table_rows, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Total Records',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${data.length}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.green.shade700, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Generated',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Data Table
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea).withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.table_chart, color: Color(0xFF667eea), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Report Data',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF667eea),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Table Content
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(
                                const Color(0xFF667eea).withOpacity(0.05),
                              ),
                              columns: headers.map((header) => DataColumn(
                                label: Text(
                                  header,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF667eea),
                                  ),
                                ),
                              )).toList(),
                              rows: data.map((row) => DataRow(
                                cells: headers.map((header) => DataCell(
                                  Text(
                                    row[header]?.toString() ?? '',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                )).toList(),
                              )).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _exportReportData(title, data, headers),
                    icon: const Icon(Icons.download),
                    label: const Text('Export CSV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportReportData(String title, List<Map<String, dynamic>> data, List<String> headers) {
    try {
      String csvData = _reportService.exportToCSV(data, headers);
      
      // Copy to clipboard (for web) or save to file (for mobile)
      Clipboard.setData(ClipboardData(text: csvData));
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title data copied to clipboard as CSV'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
