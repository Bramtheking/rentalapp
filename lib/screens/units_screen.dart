import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/unit_model.dart';
import '../services/unit_service.dart';
import '../services/auth_service.dart';
import 'add_edit_unit_screen.dart';

class UnitsScreen extends StatefulWidget {
  const UnitsScreen({Key? key}) : super(key: key);

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> with TickerProviderStateMixin {
  final UnitService _unitService = UnitService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  
  late TabController _tabController;
  Map<String, dynamic>? currentUser;
  String? selectedRentalId;
  Map<String, dynamic> unitStats = {};
  Map<String, dynamic> damageStats = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
        isLoading = false;
      });
      if (selectedRentalId != null) {
        _loadStats();
      }
    }
  }

  Future<void> _loadStats() async {
    if (selectedRentalId != null) {
      final unitStatsData = await _unitService.getUnitStats(selectedRentalId!);
      final damageStatsData = await _unitService.getDamageStats(selectedRentalId!);
      setState(() {
        unitStats = unitStatsData;
        damageStats = damageStatsData;
      });
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
        title: const Text('Unit Management'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Units'),
            Tab(text: 'Damage Control'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUnitsTab(),
          _buildDamageControlTab(),
        ],
      ),
    );
  }

  Widget _buildUnitsTab() {
    return Column(
      children: [
        // Statistics Cards
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Units',
                  unitStats['totalUnits']?.toString() ?? '0',
                  Icons.home,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Occupied Units',
                  unitStats['occupiedUnits']?.toString() ?? '0',
                  Icons.home,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Vacant Units',
                  unitStats['vacantUnits']?.toString() ?? '0',
                  Icons.home_outlined,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Under Maintenance',
                  unitStats['underMaintenance']?.toString() ?? '0',
                  Icons.build,
                  Colors.red,
                ),
              ),
            ],
          ),
        ),

        // Units List Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Units List',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Manage all rental units',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _navigateToAddUnit(),
                icon: const Icon(Icons.add),
                label: const Text('Add Unit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search units...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onChanged: (value) {
              setState(() {}); // Trigger rebuild for search
            },
          ),
        ),

        const SizedBox(height: 16),

        // Units List
        Expanded(
          child: StreamBuilder<List<Unit>>(
            stream: _unitService.getUnits(selectedRentalId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final units = snapshot.data ?? [];

              // Apply search filter
              final query = _searchController.text.toLowerCase();
              final filteredUnits = query.isEmpty
                  ? units
                  : units.where((unit) =>
                      unit.unitId.toLowerCase().contains(query) ||
                      unit.unitName.toLowerCase().contains(query) ||
                      unit.type.toLowerCase().contains(query) ||
                      (unit.tenantName?.toLowerCase().contains(query) ?? false)).toList();

              if (filteredUnits.isEmpty) {
                return const Center(
                  child: Text('No units found'),
                );
              }

              return Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
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
                        color: Colors.grey,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 1, child: Text('Unit ID', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('Unit Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 1, child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('Rent', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('Tenant', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 1, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    // Table Body
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredUnits.length,
                        itemBuilder: (context, index) {
                          final unit = filteredUnits[index];
                          return _buildUnitRow(unit);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDamageControlTab() {
    return Column(
      children: [
        // Damage Statistics
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'All',
                  damageStats['totalReports']?.toString() ?? '0',
                  Icons.report_problem,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  damageStats['pendingReports']?.toString() ?? '0',
                  Icons.pending,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'In Progress',
                  damageStats['inProgressReports']?.toString() ?? '0',
                  Icons.build,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Repaired',
                  damageStats['repairedReports']?.toString() ?? '0',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
        ),

        // Damage Control Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Damage Control',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Track and manage property damage',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _navigateToDamageReport(),
                    icon: const Icon(Icons.report),
                    label: const Text('Report Damage'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToRecordRepair(),
                    icon: const Icon(Icons.build),
                    label: const Text('Record Repair'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Damage Reports List
        Expanded(
          child: StreamBuilder<List<DamageReport>>(
            stream: _unitService.getDamageReports(selectedRentalId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final reports = snapshot.data ?? [];

              if (reports.isEmpty) {
                return const Center(
                  child: Text('No damage reports found'),
                );
              }

              return Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
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
                        color: Colors.grey,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 1, child: Text('Damage ID', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 3, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 1, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('Reported By', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('Date Reported', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 1, child: Text('Priority', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 1, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    // Table Body
                    Expanded(
                      child: ListView.builder(
                        itemCount: reports.length,
                        itemBuilder: (context, index) {
                          final report = reports[index];
                          return _buildDamageReportRow(report);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitRow(Unit unit) {
    Color statusColor = Colors.grey;
    switch (unit.status) {
      case 'occupied':
        statusColor = Colors.green;
        break;
      case 'vacant':
        statusColor = Colors.blue;
        break;
      case 'under_maintenance':
        statusColor = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text(unit.unitId)),
          Expanded(flex: 2, child: Text(unit.unitName)),
          Expanded(flex: 1, child: Text(unit.type)),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unit.status.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(flex: 2, child: Text('KES ${unit.rent.toStringAsFixed(0)}')),
          Expanded(flex: 2, child: Text(unit.tenantName ?? '-')),
          Expanded(
            flex: 1,
            child: PopupMenuButton<String>(
              onSelected: (value) => _handleUnitAction(value, unit),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'view',
                  child: ListTile(
                    leading: Icon(Icons.visibility),
                    title: Text('View Details'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDamageReportRow(DamageReport report) {
    Color statusColor = Colors.grey;
    switch (report.status) {
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        break;
      case 'repaired':
        statusColor = Colors.green;
        break;
    }

    Color priorityColor = Colors.grey;
    switch (report.priority) {
      case 'low':
        priorityColor = Colors.green;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      case 'high':
        priorityColor = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text(report.damageId)),
          Expanded(flex: 3, child: Text(report.description, maxLines: 2, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 1, child: Text(report.unitName)),
          Expanded(flex: 2, child: Text(report.reportedBy)),
          Expanded(flex: 2, child: Text(report.dateReported.toString().split(' ')[0])),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                report.status.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                report.priority.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: PopupMenuButton<String>(
              onSelected: (value) => _handleDamageAction(value, report),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: ListTile(
                    leading: Icon(Icons.visibility),
                    title: Text('View'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleUnitAction(String action, Unit unit) {
    switch (action) {
      case 'edit':
        _navigateToEditUnit(unit);
        break;
      case 'view':
        _showUnitDetails(unit);
        break;
      case 'delete':
        _showDeleteUnitDialog(unit);
        break;
    }
  }

  void _handleDamageAction(String action, DamageReport report) {
    switch (action) {
      case 'view':
        _showDamageDetails(report);
        break;
      case 'edit':
        _navigateToEditDamageReport(report);
        break;
      case 'delete':
        _showDeleteDamageDialog(report);
        break;
    }
  }

  void _navigateToAddUnit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditUnitScreen(
          rentalId: selectedRentalId!,
        ),
      ),
    ).then((_) => _loadStats());
  }

  void _navigateToEditUnit(Unit unit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditUnitScreen(
          rentalId: selectedRentalId!,
          unit: unit,
        ),
      ),
    ).then((_) => _loadStats());
  }

  void _navigateToDamageReport() {
    // TODO: Implement damage report navigation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Damage report feature coming soon')),
    );
  }

  void _navigateToRecordRepair() {
    // TODO: Implement record repair screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Record repair feature coming soon')),
    );
  }

  void _navigateToEditDamageReport(DamageReport report) {
    // TODO: Implement edit damage report navigation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit damage report feature coming soon')),
    );
  }

  void _showUnitDetails(Unit unit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unit ${unit.unitId}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Unit Name', unit.unitName),
              _buildDetailRow('Type', unit.type),
              _buildDetailRow('Status', unit.status),
              _buildDetailRow('Rent', 'KES ${unit.rent.toStringAsFixed(2)}'),
              _buildDetailRow('Bedrooms', unit.bedrooms.toString()),
              _buildDetailRow('Bathrooms', unit.bathrooms.toString()),
              if (unit.area != null)
                _buildDetailRow('Area', '${unit.area!.toStringAsFixed(0)} sq ft'),
              if (unit.tenantName != null)
                _buildDetailRow('Tenant', unit.tenantName!),
              if (unit.description != null && unit.description!.isNotEmpty)
                _buildDetailRow('Description', unit.description!),
              if (unit.amenities.isNotEmpty)
                _buildDetailRow('Amenities', unit.amenities.join(', ')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDamageDetails(DamageReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Damage Report ${report.damageId}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Description', report.description),
              _buildDetailRow('Unit', report.unitName),
              _buildDetailRow('Reported By', report.reportedBy),
              _buildDetailRow('Date Reported', report.dateReported.toString().split(' ')[0]),
              _buildDetailRow('Status', report.status),
              _buildDetailRow('Priority', report.priority),
              if (report.repairNotes != null)
                _buildDetailRow('Repair Notes', report.repairNotes!),
              if (report.repairDate != null)
                _buildDetailRow('Repair Date', report.repairDate.toString().split(' ')[0]),
              if (report.repairCost != null)
                _buildDetailRow('Repair Cost', 'KES ${report.repairCost!.toStringAsFixed(2)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showDeleteUnitDialog(Unit unit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Unit'),
        content: Text('Are you sure you want to delete unit ${unit.unitId}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _unitService.deleteUnit(selectedRentalId!, unit.id);
              Navigator.pop(context);
              _loadStats();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unit deleted successfully')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDamageDialog(DamageReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Damage Report'),
        content: Text('Are you sure you want to delete damage report ${report.damageId}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _unitService.deleteDamageReport(selectedRentalId!, report.id);
              Navigator.pop(context);
              _loadStats();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Damage report deleted successfully')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}