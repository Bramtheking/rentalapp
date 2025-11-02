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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF667eea),
                Color(0xFF764ba2),
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    if (selectedRentalId == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF667eea),
                Color(0xFF764ba2),
              ],
            ),
          ),
          child: const Center(
            child: Text(
              'No rental assigned to your account',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

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
              // Beautiful Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
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
                            Icons.people_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tenant Management',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Manage your property tenants',
                                style: TextStyle(
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
                            icon: const Icon(Icons.add_rounded, color: Colors.white),
                            onPressed: () => _navigateToAddTenant(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Beautiful Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search tenants...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.7)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        onChanged: (value) {
                          setState(() {}); // Trigger rebuild for search
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              // Statistics Cards
              Container(
                height: 120,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModernStatCard(
                        'Total Tenants',
                        stats['totalTenants']?.toString() ?? '0',
                        Icons.people_rounded,
                        const Color(0xFF667eea),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModernStatCard(
                        'Active',
                        stats['activeTenants']?.toString() ?? '0',
                        Icons.check_circle_rounded,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModernStatCard(
                        'Moved Out',
                        stats['movedOutTenants']?.toString() ?? '0',
                        Icons.person_remove_rounded,
                        const Color(0xFFf093fb),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Tenants List
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: StreamBuilder<List<Tenant>>(
                    stream: _tenantService.getTenants(selectedRentalId!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                          ),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
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
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No tenants found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: filteredTenants.length,
                        itemBuilder: (context, index) {
                          final tenant = filteredTenants[index];
                          return _buildModernTenantCard(tenant);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernTenantCard(Tenant tenant) {
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showTenantDetails(tenant),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: tenant.status == 'active' 
                          ? [Colors.green, Colors.green.shade300]
                          : [const Color(0xFFf093fb), const Color(0xFFf093fb).withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      tenant.name.isNotEmpty ? tenant.name[0].toUpperCase() : 'T',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.home_rounded, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Unit ${tenant.unitNumber}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.attach_money_rounded, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '\$${tenant.rentAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: tenant.status == 'active' 
                              ? Colors.green.withOpacity(0.1)
                              : const Color(0xFFf093fb).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tenant.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tenant.status == 'active' 
                                ? Colors.green
                                : const Color(0xFFf093fb),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleMenuAction(value, tenant),
                  icon: Icon(Icons.more_vert_rounded, color: Colors.grey[400]),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_rounded, color: Color(0xFF667eea)),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (tenant.status == 'active')
                      const PopupMenuItem(
                        value: 'move_out',
                        child: ListTile(
                          leading: Icon(Icons.exit_to_app_rounded, color: Colors.orange),
                          title: Text('Move Out'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_rounded, color: Colors.red),
                        title: Text('Delete', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: tenant.status == 'active' 
                      ? [Colors.green, Colors.green.shade300]
                      : [const Color(0xFFf093fb), const Color(0xFFf093fb).withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  tenant.name.isNotEmpty ? tenant.name[0].toUpperCase() : 'T',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(tenant.name),
          ],
        ),
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
            child: const Text('Close', style: TextStyle(color: Color(0xFF667eea))),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                trailing: const Icon(Icons.calendar_today, color: Color(0xFF667eea)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Tenant'),
        content: Text('Are you sure you want to delete ${tenant.name}? This action cannot be undone.'),
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