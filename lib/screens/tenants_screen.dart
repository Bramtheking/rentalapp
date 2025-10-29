import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/tenant_model.dart';
import '../services/tenant_service.dart';
import '../services/auth_service.dart';
import 'add_edit_tenant_screen.dart';

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  final TenantService _tenantService = TenantService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  
  Map<String, dynamic>? currentUser;
  String? selectedRentalId;
  List<Tenant> filteredTenants = [];
  Map<String, dynamic> stats = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
      final statsData = await _tenantService.getTenantStats(selectedRentalId!);
      setState(() {
        stats = statsData;
      });
    }
  }

  void _filterTenants(List<Tenant> tenants) {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredTenants = tenants.where((tenant) =>
          tenant.name.toLowerCase().contains(query) ||
          tenant.email.toLowerCase().contains(query) ||
          tenant.phone.contains(query) ||
          tenant.unitNumber.toLowerCase().contains(query)).toList();
    });
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
        title: const Text('Tenants Management'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToAddTenant(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Cards
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Tenants',
                        stats['totalTenants']?.toString() ?? '0',
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Active',
                        stats['activeTenants']?.toString() ?? '0',
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Moved Out',
                        stats['movedOutTenants']?.toString() ?? '0',
                        Icons.person_remove,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Total Rent',
                        '\$${stats['totalRentAmount']?.toStringAsFixed(0) ?? '0'}',
                        Icons.attach_money,
                        Colors.purple,
                      ),
                    ),
                  ],
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
                hintText: 'Search tenants...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                // Trigger search when typing
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Tenants List
          Expanded(
            child: StreamBuilder<List<Tenant>>(
              stream: _tenantService.getTenants(selectedRentalId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final tenants = snapshot.data ?? [];
                
                // Apply search filter
                final query = _searchController.text.toLowerCase();
                final filteredTenants = query.isEmpty 
                    ? tenants 
                    : tenants.where((tenant) =>
                        tenant.name.toLowerCase().contains(query) ||
                        tenant.email.toLowerCase().contains(query) ||
                        tenant.phone.contains(query) ||
                        tenant.unitNumber.toLowerCase().contains(query)).toList();
                
                if (filteredTenants.isEmpty) {
                  return const Center(
                    child: Text('No tenants found'),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredTenants.length,
                  itemBuilder: (context, index) {
                    final tenant = filteredTenants[index];
                    return _buildTenantCard(tenant);
                  },
                );
              },
            ),
          ),
        ],
      ),
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

  Widget _buildTenantCard(Tenant tenant) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: tenant.status == 'active' ? Colors.green : Colors.orange,
          child: Text(
            tenant.name.isNotEmpty ? tenant.name[0].toUpperCase() : 'T',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          tenant.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unit: ${tenant.unitNumber}'),
            Text('Rent: \$${tenant.rentAmount.toStringAsFixed(0)}'),
            Text('Status: ${tenant.status}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value, tenant),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
              ),
            ),
            if (tenant.status == 'active')
              const PopupMenuItem(
                value: 'move_out',
                child: ListTile(
                  leading: Icon(Icons.exit_to_app),
                  title: Text('Move Out'),
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
        onTap: () => _showTenantDetails(tenant),
      ),
    );
  }

  void _handleMenuAction(String action, Tenant tenant) {
    switch (action) {
      case 'edit':
        _navigateToEditTenant(tenant);
        break;
      case 'move_out':
        _showMoveOutDialog(tenant);
        break;
      case 'delete':
        _showDeleteDialog(tenant);
        break;
    }
  }

  void _navigateToAddTenant() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditTenantScreen(
          rentalId: selectedRentalId!,
        ),
      ),
    ).then((_) => _loadStats());
  }

  void _navigateToEditTenant(Tenant tenant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditTenantScreen(
          rentalId: selectedRentalId!,
          tenant: tenant,
        ),
      ),
    ).then((_) => _loadStats());
  }

  void _showTenantDetails(Tenant tenant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tenant.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', tenant.email),
              _buildDetailRow('Phone', tenant.phone),
              _buildDetailRow('Unit', tenant.unitNumber),
              _buildDetailRow('Rent', '\$${tenant.rentAmount.toStringAsFixed(2)}'),
              _buildDetailRow('Move In', tenant.moveInDate.toString().split(' ')[0]),
              if (tenant.moveOutDate != null)
                _buildDetailRow('Move Out', tenant.moveOutDate.toString().split(' ')[0]),
              _buildDetailRow('Status', tenant.status),
              if (tenant.emergencyContact != null)
                _buildDetailRow('Emergency Contact', tenant.emergencyContact!),
              if (tenant.emergencyPhone != null)
                _buildDetailRow('Emergency Phone', tenant.emergencyPhone!),
              if (tenant.securityDeposit != null)
                _buildDetailRow('Security Deposit', '\$${tenant.securityDeposit!.toStringAsFixed(2)}'),
              if (tenant.notes != null && tenant.notes!.isNotEmpty)
                _buildDetailRow('Notes', tenant.notes!),
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

  void _showMoveOutDialog(Tenant tenant) {
    DateTime selectedDate = DateTime.now();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move Out Tenant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Move out ${tenant.name}?'),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setState) => ListTile(
                title: const Text('Move Out Date'),
                subtitle: Text(selectedDate.toString().split(' ')[0]),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: tenant.moveInDate,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => selectedDate = date);
                  }
                },
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
            onPressed: () async {
              await _tenantService.moveOutTenant(
                selectedRentalId!,
                tenant.id,
                selectedDate,
              );
              Navigator.pop(context);
              _loadStats();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tenant moved out successfully')),
              );
            },
            child: const Text('Move Out'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Tenant tenant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tenant'),
        content: Text('Are you sure you want to delete ${tenant.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _tenantService.deleteTenant(selectedRentalId!, tenant.id);
              Navigator.pop(context);
              _loadStats();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tenant deleted successfully')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}