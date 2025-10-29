import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/dashboard_service.dart';
import 'super_admin_dashboard.dart';
import 'tenants_screen.dart';
import 'units_screen.dart';
import 'sms_screen.dart';
import 'expenses_screen.dart';
import 'reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _selectedBuildingId;
  String _selectedBuildingName = 'Select Building';

  final List<String> _pageNames = [
    'Dashboard',
    'Rent Payments',
    'Tenant Management',
    'Unit Management',
    'SMS Communications',
    'Expenses',
    'Reports',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 250,
            color: Colors.grey[50],
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.orange,
                  child: const Row(
                    children: [
                      Icon(Icons.business, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'RentManager Pro',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Building Status Indicator
                if (_selectedBuildingId == null)
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.warning, color: Colors.red[400], size: 20),
                        const SizedBox(height: 4),
                        const Text(
                          'No Building Selected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const Text(
                          'Select a building to access features',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                
                // Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildNavItem(Icons.dashboard, 'Dashboard', 0),
                      _buildNavItem(Icons.payment, 'Rent Payments', 1),
                      _buildNavItem(Icons.people, 'Tenant Management', 2),
                      _buildNavItem(Icons.home_work, 'Unit Management', 3),
                      _buildNavItem(Icons.sms, 'SMS Communications', 4),
                      _buildNavItem(Icons.receipt_long, 'Expenses', 5),
                      _buildNavItem(Icons.analytics, 'Reports', 6),
                      const Divider(),
                      _buildNavItem(Icons.person, 'Profile', 7),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, int index) {
    final isSelected = _selectedIndex == index;
    final requiresBuilding = _requiresBuilding(index);
    final isDisabled = requiresBuilding && _selectedBuildingId == null;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isDisabled 
                  ? Colors.grey[400]
                  : (isSelected ? Colors.orange : Colors.grey[600]),
            ),
            if (isDisabled) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.lock,
                size: 12,
                color: Colors.grey[400],
              ),
            ],
          ],
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDisabled 
                ? Colors.grey[400]
                : (isSelected ? Colors.orange : Colors.grey[800]),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.orange.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onTap: isDisabled 
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a building first from the Dashboard'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            : () {
                setState(() {
                  _selectedIndex = index;
                });
              },
      ),
    );
  }

  bool _requiresBuilding(int index) {
    // Dashboard (0) and Profile (7) don't require building selection
    return index != 0 && index != 7;
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return DashboardPage(
          selectedBuildingId: _selectedBuildingId,
          selectedBuildingName: _selectedBuildingName,
          onBuildingChanged: (id, name) {
            setState(() {
              _selectedBuildingId = id;
              _selectedBuildingName = name;
            });
          },
          onAddBuilding: () => _showAddBuildingDialog(context),
        );
      case 1:
        return _buildingRequired(RentPaymentsPage(selectedBuildingId: _selectedBuildingId));
      case 2:
        return _buildingRequired(const TenantsScreen());
      case 3:
        return _buildingRequired(const UnitsScreen());
      case 4:
        return _buildingRequired(const SMSScreen());
      case 5:
        return _buildingRequired(const ExpensesScreen());
      case 6:
        return _buildingRequired(const ReportsScreen());
      case 7:
        return const ProfilePage();
      default:
        return DashboardPage(
          selectedBuildingId: _selectedBuildingId,
          selectedBuildingName: _selectedBuildingName,
          onBuildingChanged: (id, name) {
            setState(() {
              _selectedBuildingId = id;
              _selectedBuildingName = name;
            });
          },
          onAddBuilding: () => _showAddBuildingDialog(context),
        );
    }
  }

  Widget _buildingRequired(Widget child) {
    if (_selectedBuildingId == null) {
      return _buildNoBuildingSelectedScreen();
    }
    return child;
  }

  Widget _buildNoBuildingSelectedScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.business,
                size: 80,
                color: Colors.orange[300],
              ),
              const SizedBox(height: 24),
              const Text(
                'No Building Selected',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please select or create a building from the Dashboard to access this feature.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedIndex = 0; // Go to Dashboard
                      });
                    },
                    icon: const Icon(Icons.dashboard),
                    label: const Text('Go to Dashboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () => _showAddBuildingDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Building'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
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

  void _showAddBuildingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddBuildingDialog(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  final String? selectedBuildingId;
  final String selectedBuildingName;
  final Function(String?, String) onBuildingChanged;
  final VoidCallback onAddBuilding;

  const DashboardPage({
    super.key,
    required this.selectedBuildingId,
    required this.selectedBuildingName,
    required this.onBuildingChanged,
    required this.onAddBuilding,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DashboardService _dashboardService = DashboardService();
  Map<String, dynamic> dashboardData = {};
  List<Map<String, dynamic>> monthlyTrends = [];
  bool isLoadingData = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedBuildingId != null) {
      _loadDashboardData();
    }
  }

  @override
  void didUpdateWidget(DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedBuildingId != oldWidget.selectedBuildingId) {
      if (widget.selectedBuildingId != null) {
        _loadDashboardData();
      } else {
        setState(() {
          dashboardData = {};
          monthlyTrends = [];
        });
      }
    }
  }

  Future<void> _loadDashboardData() async {
    if (widget.selectedBuildingId == null) return;
    
    setState(() {
      isLoadingData = true;
    });

    try {
      final data = await _dashboardService.getDashboardData(widget.selectedBuildingId!);
      final trends = await _dashboardService.getMonthlyTrends(widget.selectedBuildingId!);
      
      setState(() {
        dashboardData = data;
        monthlyTrends = trends;
        isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        isLoadingData = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading dashboard data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          // Add Building Button
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: widget.onAddBuilding,
            tooltip: 'Add Building',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: widget.selectedBuildingId != null ? _loadDashboardData : null,
            tooltip: 'Refresh Data',
          ),
          FutureBuilder<Map<String, dynamic>?>(
            future: AuthService().getUserData(FirebaseAuth.instance.currentUser!.uid),
            builder: (context, snapshot) {
              final userType = snapshot.hasData && snapshot.data != null 
                  ? snapshot.data!['userType'] ?? '' 
                  : '';
              
              return PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'logout') {
                    await AuthService().signOut();
                  } else if (value == 'admin') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SuperAdminDashboard(),
                      ),
                    );
                  }
                },
                itemBuilder: (BuildContext context) {
                  List<PopupMenuEntry<String>> items = [];
                  
                  // Add admin option only for super admin users
                  if (userType == 'superadmin') {
                    items.add(
                      const PopupMenuItem<String>(
                        value: 'admin',
                        child: Row(
                          children: [
                            Icon(Icons.admin_panel_settings, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Super Admin'),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  // Always add logout option
                  items.add(
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Sign Out'),
                        ],
                      ),
                    ),
                  );
                  
                  return items;
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Building Selector
            _buildBuildingSelector(),
            const SizedBox(height: 16),
            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome to RentEasy!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Find your perfect rental property',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.orange,
                    ),
                    child: const Text('Start Exploring'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Dashboard Content
            if (widget.selectedBuildingId != null) ...[
              if (isLoadingData) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ] else if (dashboardData.isNotEmpty) ...[
                // Financial Overview Cards
                _buildFinancialOverview(),
                const SizedBox(height: 24),
                
                // Charts Section
                _buildChartsSection(),
                const SizedBox(height: 24),
                
                // Property Statistics
                _buildPropertyStatistics(),
                const SizedBox(height: 24),
                
                // Quick Actions
                _buildQuickActionsSection(),
              ] else ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No data available for this building'),
                  ),
                ),
              ],
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.business,
                      size: 64,
                      color: Colors.blue[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Get Started with Your First Building',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create or select a building to start managing tenants, units, expenses, and more.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: widget.onAddBuilding,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Your First Building'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Building Selector Widget
  Widget _buildBuildingSelector() {
    final hasBuilding = widget.selectedBuildingId != null;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasBuilding 
            ? Colors.orange.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasBuilding 
              ? Colors.orange.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
          width: hasBuilding ? 1 : 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasBuilding ? Icons.business : Icons.warning,
            color: hasBuilding ? Colors.orange : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rentals')
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('Loading buildings...');
                }

                final buildings = snapshot.data!.docs;
                
                return DropdownButton<String>(
                  value: widget.selectedBuildingId,
                  hint: Text(widget.selectedBuildingName),
                  isExpanded: true,
                  underline: Container(),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Select Building'),
                    ),
                    ...buildings.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(data['name'] ?? 'Unknown Building'),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    String newName = 'Select Building';
                    if (value != null) {
                      final building = buildings.firstWhere((doc) => doc.id == value);
                      final data = building.data() as Map<String, dynamic>;
                      newName = data['name'] ?? 'Unknown Building';
                    }
                    widget.onBuildingChanged(value, newName);
                  },
                );
              },
            ),
          ),
          if (widget.selectedBuildingId != null) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.orange),
              onSelected: (value) => _handleBuildingAction(value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Edit Building'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Building'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _handleBuildingAction(String action) {
    if (widget.selectedBuildingId == null) return;
    
    if (action == 'edit') {
      _showEditBuildingDialog();
    } else if (action == 'delete') {
      _showDeleteBuildingConfirmation();
    }
  }

  void _showEditBuildingDialog() {
    showDialog(
      context: context,
      builder: (context) => EditBuildingDialog(buildingId: widget.selectedBuildingId!),
    );
  }

  void _showDeleteBuildingConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Building'),
        content: Text('Are you sure you want to delete "${widget.selectedBuildingName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('rentals')
                    .doc(widget.selectedBuildingId)
                    .update({'isActive': false});
                
                widget.onBuildingChanged(null, 'Select Building');
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Building deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting building: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }



  Widget _buildFinancialOverview() {
    final financial = dashboardData['financial'] ?? {};
    final payments = dashboardData['payments'] ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Financial Overview',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Income',
                'KES ${_formatCurrency(financial['totalIncome'] ?? 0)}',
                Icons.trending_up,
                Colors.green,
                subtitle: payments['growthRate'] != null 
                    ? '${payments['growthRate'].toStringAsFixed(1)}% vs last month'
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Total Expenses',
                'KES ${_formatCurrency(financial['totalExpenses'] ?? 0)}',
                Icons.trending_down,
                Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Net Profit',
                'KES ${_formatCurrency(financial['netProfit'] ?? 0)}',
                Icons.account_balance_wallet,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Occupancy Rate',
                '${(financial['occupancyRate'] ?? 0).toStringAsFixed(1)}%',
                Icons.home,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analytics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // Monthly Trends Chart
            Expanded(
              flex: 2,
              child: Container(
                height: 300,
                padding: const EdgeInsets.all(16),
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
                    const Text(
                      'Monthly Trends',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _buildMonthlyTrendsChart()),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Occupancy Pie Chart
            Expanded(
              child: Container(
                height: 300,
                padding: const EdgeInsets.all(16),
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
                    const Text(
                      'Unit Occupancy',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _buildOccupancyChart()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPropertyStatistics() {
    final units = dashboardData['units'] ?? {};
    final tenants = dashboardData['tenants'] ?? {};
    final payments = dashboardData['payments'] ?? {};
    final expenses = dashboardData['expenses'] ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Property Statistics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Units',
                '${units['totalUnits'] ?? 0}',
                Icons.home_work,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Active Tenants',
                '${tenants['activeTenants'] ?? 0}',
                Icons.people,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Payments This Month',
                '${payments['paymentsCount'] ?? 0}',
                Icons.payment,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Expenses This Month',
                '${expenses['expensesCount'] ?? 0}',
                Icons.receipt,
                Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.people,
                title: 'Manage Tenants',
                onTap: () {
                  // Navigate to tenants screen
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.home_work,
                title: 'Manage Units',
                onTap: () {
                  // Navigate to units screen
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.payment,
                title: 'Record Payment',
                onTap: () {
                  // Navigate to payments screen
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.receipt,
                title: 'Add Expense',
                onTap: () {
                  // Navigate to expenses screen
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.green[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendsChart() {
    if (monthlyTrends.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return Column(
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Income', Colors.green),
            const SizedBox(width: 16),
            _buildLegendItem('Expenses', Colors.red),
          ],
        ),
        const SizedBox(height: 16),
        // Simple bar chart representation
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: monthlyTrends.map((trend) {
              final income = trend['income'] as double;
              final expenses = trend['expenses'] as double;
              final maxValue = monthlyTrends.fold<double>(0, (max, t) => 
                  [max, t['income'] as double, t['expenses'] as double].reduce((a, b) => a > b ? a : b));
              
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Income bar
                      Container(
                        width: 20,
                        height: maxValue > 0 ? (income / maxValue * 100) : 0,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Expenses bar
                      Container(
                        width: 20,
                        height: maxValue > 0 ? (expenses / maxValue * 100) : 0,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Month label
                      Text(
                        trend['monthName'],
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildOccupancyChart() {
    final units = dashboardData['units'] ?? {};
    final occupied = units['occupiedUnits'] ?? 0;
    final vacant = units['vacantUnits'] ?? 0;
    final maintenance = units['maintenanceUnits'] ?? 0;
    final total = occupied + vacant + maintenance;
    
    if (total == 0) {
      return const Center(child: Text('No units data'));
    }

    return Column(
      children: [
        // Donut chart representation
        Expanded(
          child: Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                children: [
                  // Background circle
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[300]!, width: 20),
                    ),
                  ),
                  // Occupied arc
                  if (occupied > 0)
                    CustomPaint(
                      size: const Size(120, 120),
                      painter: ArcPainter(
                        percentage: occupied / total,
                        color: Colors.green,
                        startAngle: 0,
                      ),
                    ),
                  // Vacant arc
                  if (vacant > 0)
                    CustomPaint(
                      size: const Size(120, 120),
                      painter: ArcPainter(
                        percentage: vacant / total,
                        color: Colors.blue,
                        startAngle: (occupied / total) * 2 * 3.14159,
                      ),
                    ),
                  // Maintenance arc
                  if (maintenance > 0)
                    CustomPaint(
                      size: const Size(120, 120),
                      painter: ArcPainter(
                        percentage: maintenance / total,
                        color: Colors.orange,
                        startAngle: ((occupied + vacant) / total) * 2 * 3.14159,
                      ),
                    ),
                  // Center text
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Total Units',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Column(
          children: [
            if (occupied > 0)
              _buildOccupancyLegend('Occupied', occupied, Colors.green),
            if (vacant > 0)
              _buildOccupancyLegend('Vacant', vacant, Colors.blue),
            if (maintenance > 0)
              _buildOccupancyLegend('Maintenance', maintenance, Colors.orange),
          ],
        ),
      ],
    );
  }

  Widget _buildOccupancyLegend(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text('$label: $count', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: Colors.orange,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ArcPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final double startAngle;

  ArcPainter({
    required this.percentage,
    required this.color,
    required this.startAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 20) / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      percentage * 2 * 3.14159,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.orange,
            ),
            SizedBox(height: 16),
            Text(
              'Search Page',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Search functionality will be implemented here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite,
              size: 64,
              color: Colors.orange,
            ),
            SizedBox(height: 16),
            Text(
              'Favorites Page',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your favorite properties will appear here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person,
              size: 64,
              color: Colors.orange,
            ),
            SizedBox(height: 16),
            Text(
              'Profile Page',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'User profile and settings will be here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// Add Building Dialog
class AddBuildingDialog extends StatefulWidget {
  const AddBuildingDialog({super.key});

  @override
  State<AddBuildingDialog> createState() => _AddBuildingDialogState();
}

class _AddBuildingDialogState extends State<AddBuildingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalUnitsController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _totalUnitsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.business, color: Colors.orange),
          SizedBox(width: 8),
          Text('Add New Building'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Building Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter building name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _totalUnitsController,
                decoration: const InputDecoration(
                  labelText: 'Total Units *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.home),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter total units';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Please enter a valid number of units';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addBuilding,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Add Building'),
        ),
      ],
    );
  }

  void _addBuilding() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await FirebaseFirestore.instance.collection('rentals').add({
          'name': _nameController.text.trim(),
          'address': _addressController.text.trim(),
          'totalUnits': int.parse(_totalUnitsController.text.trim()),
          'description': _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'createdBy': FirebaseAuth.instance.currentUser?.uid,
        });

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Building added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// Rent Payments Page
class RentPaymentsPage extends StatefulWidget {
  final String? selectedBuildingId;

  const RentPaymentsPage({super.key, this.selectedBuildingId});

  @override
  State<RentPaymentsPage> createState() => _RentPaymentsPageState();
}

class _RentPaymentsPageState extends State<RentPaymentsPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rent Payments'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Payments'),
            Tab(text: 'Payment Receipts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPaymentsTab(),
          _buildReceiptsTab(),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab() {
    return Column(
      children: [
        // Header with search and add button
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by unit, tenant...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {}); // Trigger rebuild for search
                  },
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showAddPaymentDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Payment History Table
        Expanded(
          child: Container(
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
                      Expanded(flex: 2, child: Text('Tenant', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Method', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                // Table Body
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getPaymentsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text('No payments found'),
                        );
                      }

                      final payments = snapshot.data!.docs;
                      final filteredPayments = _filterPayments(payments);

                      return ListView.builder(
                        itemCount: filteredPayments.length,
                        itemBuilder: (context, index) {
                          final payment = filteredPayments[index];
                          final data = payment.data() as Map<String, dynamic>;
                          
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 2, child: Text(data['tenantName'] ?? 'Unknown')),
                                Expanded(flex: 1, child: Text(data['unit'] ?? 'N/A')),
                                Expanded(flex: 2, child: Text('KES ${data['amount'] ?? 0}')),
                                Expanded(flex: 2, child: Text(data['date'] ?? 'N/A')),
                                Expanded(flex: 2, child: Text(data['method'] ?? 'N/A')),
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: data['status'] == 'Completed' ? Colors.green : Colors.orange,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      data['status'] ?? 'Pending',
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: PopupMenuButton<String>(
                                    onSelected: (value) => _handlePaymentAction(payment.id, value),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'view', child: Text('View')),
                                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptsTab() {
    return Column(
      children: [
        // Header with search and generate receipt button
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by receipt, unit...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download),
                label: const Text('Export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.receipt),
                label: const Text('Generate Receipt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Receipts Table
        Expanded(
          child: Container(
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
                      Expanded(flex: 1, child: Text('Receipt No', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Tenant', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Payment Date', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Method', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                // Sample Receipt Data
                Expanded(
                  child: ListView(
                    children: [
                      _buildReceiptRow('RCP-001', 'John Doe', 'A-101', '2024-01-15', 'KES 25,000', 'M-Pesa', 'Generated'),
                      _buildReceiptRow('RCP-002', 'Jane Smith', 'B-205', '2024-01-14', 'KES 30,000', 'Bank Transfer', 'Generated'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptRow(String receiptNo, String tenant, String unit, String date, String amount, String method, String status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text(receiptNo)),
          Expanded(flex: 2, child: Text(tenant)),
          Expanded(flex: 1, child: Text(unit)),
          Expanded(flex: 2, child: Text(date)),
          Expanded(flex: 2, child: Text(amount)),
          Expanded(flex: 2, child: Text(method)),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                TextButton(
                  onPressed: () {},
                  child: const Text('View'),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Download'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getPaymentsStream() {
    // Get current user's rental name
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) async* {
      if (user != null) {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final userData = userDoc.data();
          final rentalName = userData?['rental'] as String?;
          
          if (rentalName != null && rentalName.isNotEmpty) {
            // Get payments from the user's rental subcollection
            yield* FirebaseFirestore.instance
                .collection('rentals')
                .doc(rentalName)
                .collection('payments')
                .orderBy('createdAt', descending: true)
                .snapshots();
          } else {
            // No rental assigned - return empty stream
            yield* Stream.value(
              await FirebaseFirestore.instance.collection('empty').limit(0).get()
            );
          }
        } catch (e) {
          print('Error getting payments stream: $e');
          yield* Stream.value(
            await FirebaseFirestore.instance.collection('empty').limit(0).get()
          );
        }
      } else {
        yield* Stream.value(
          await FirebaseFirestore.instance.collection('empty').limit(0).get()
        );
      }
    });
  }

  List<QueryDocumentSnapshot> _filterPayments(List<QueryDocumentSnapshot> payments) {
    if (_searchController.text.isEmpty) return payments;
    
    final searchTerm = _searchController.text.toLowerCase();
    return payments.where((payment) {
      final data = payment.data() as Map<String, dynamic>;
      final tenantName = (data['tenantName'] ?? '').toString().toLowerCase();
      final unit = (data['unit'] ?? '').toString().toLowerCase();
      
      return tenantName.contains(searchTerm) || unit.contains(searchTerm);
    }).toList();
  }

  void _showAddPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddPaymentDialog(),
    );
  }

  void _handlePaymentAction(String paymentId, String action) {
    switch (action) {
      case 'view':
        // TODO: Show payment details
        break;
      case 'edit':
        // TODO: Edit payment
        break;
      case 'delete':
        _showDeletePaymentConfirmation(paymentId);
        break;
    }
  }

  void _showDeletePaymentConfirmation(String paymentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment'),
        content: const Text('Are you sure you want to delete this payment? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  // Get user's rental name
                  final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                  final userData = userDoc.data();
                  final rentalName = userData?['rental'] as String?;
                  
                  if (rentalName != null && rentalName.isNotEmpty) {
                    await FirebaseFirestore.instance
                        .collection('rentals')
                        .doc(rentalName)
                        .collection('payments')
                        .doc(paymentId)
                        .delete();
                    
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting payment: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Add Payment Dialog
class AddPaymentDialog extends StatefulWidget {
  const AddPaymentDialog({super.key});

  @override
  State<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tenantController = TextEditingController();
  final _unitController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  String _selectedMethod = 'M-Pesa';
  String _selectedStatus = 'Completed';
  bool _isLoading = false;

  final List<String> _paymentMethods = ['M-Pesa', 'Bank Transfer', 'Cash', 'Cheque'];
  final List<String> _statusOptions = ['Completed', 'Pending', 'Failed'];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateTime.now().toString().split(' ')[0];
  }

  @override
  void dispose() {
    _tenantController.dispose();
    _unitController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.payment, color: Colors.orange),
          SizedBox(width: 8),
          Text('Add Payment'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _tenantController,
                decoration: const InputDecoration(
                  labelText: 'Tenant Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Please enter tenant name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(
                  labelText: 'Unit *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Please enter unit' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (KES) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter amount';
                  if (double.tryParse(value!) == null) return 'Please enter valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Payment Date *',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    _dateController.text = date.toString().split(' ')[0];
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
                items: _paymentMethods.map((method) {
                  return DropdownMenuItem(value: method, child: Text(method));
                }).toList(),
                onChanged: (value) => setState(() => _selectedMethod = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: _statusOptions.map((status) {
                  return DropdownMenuItem(value: status, child: Text(status));
                }).toList(),
                onChanged: (value) => setState(() => _selectedStatus = value!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
              : const Text('Add Payment'),
        ),
      ],
    );
  }

  void _addPayment() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Get user's rental name
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final userData = userDoc.data();
          final rentalName = userData?['rental'] as String?;
          
          if (rentalName != null && rentalName.isNotEmpty) {
            // Add payment to user's rental subcollection
            await FirebaseFirestore.instance
                .collection('rentals')
                .doc(rentalName)
                .collection('payments')
                .add({
              'tenantName': _tenantController.text.trim(),
              'unit': _unitController.text.trim(),
              'amount': double.parse(_amountController.text.trim()),
              'date': _dateController.text,
              'method': _selectedMethod,
              'status': _selectedStatus,
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': user.uid,
              'rentalName': rentalName,
            });

            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment added successfully!'), backgroundColor: Colors.green),
            );
          } else {
            throw Exception('No rental assigned to user. Please contact admin.');
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
}

// Edit Building Dialog
class EditBuildingDialog extends StatefulWidget {
  final String buildingId;

  const EditBuildingDialog({super.key, required this.buildingId});

  @override
  State<EditBuildingDialog> createState() => _EditBuildingDialogState();
}

class _EditBuildingDialogState extends State<EditBuildingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalUnitsController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBuildingData();
  }

  void _loadBuildingData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rentals')
          .doc(widget.buildingId)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _addressController.text = data['address'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _totalUnitsController.text = (data['totalUnits'] ?? 0).toString();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading building data: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit, color: Colors.orange),
          SizedBox(width: 8),
          Text('Edit Building'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Building Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Please enter building name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Please enter address' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _totalUnitsController,
                decoration: const InputDecoration(
                  labelText: 'Total Units *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter total units';
                  if (int.tryParse(value!) == null || int.parse(value) <= 0) return 'Please enter valid number of units';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateBuilding,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : const Text('Update'),
        ),
      ],
    );
  }

  void _updateBuilding() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        await FirebaseFirestore.instance.collection('rentals').doc(widget.buildingId).update({
          'name': _nameController.text.trim(),
          'address': _addressController.text.trim(),
          'totalUnits': int.parse(_totalUnitsController.text.trim()),
          'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Building updated successfully!'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
}

// Tenant Management Page
class TenantManagementPage extends StatefulWidget {
  const TenantManagementPage({super.key});

  @override
  State<TenantManagementPage> createState() => _TenantManagementPageState();
}

class _TenantManagementPageState extends State<TenantManagementPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tenant Management'),
            Text(
              'Manage tenants and move in/out processes',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tenants'),
            Tab(text: 'Move In/Out Process'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTenantsTab(),
          _buildMoveInOutTab(),
        ],
      ),
    );
  }

  Widget _buildTenantsTab() {
    return Column(
      children: [
        // Statistics Cards
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: _buildStatCard('All Tenants', '82', Colors.orange, Icons.people)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Tenants with Arrears', '12', Colors.red, Icons.warning)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Current Tenants', '70', Colors.green, Icons.check_circle)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _buildStatCard('Good Standing', '58', Colors.blue, Icons.thumb_up)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Vacated Tenants', '8', Colors.grey, Icons.home)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Deposit-defaulters', '4', Colors.purple, Icons.money_off)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Tenants List Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tenants List',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Manage all your tenants',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddTenantDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Tenant'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search tenants...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) => setState(() {}),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Tenants Table
        Expanded(
          child: Container(
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
                      Expanded(flex: 2, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                // Table Body
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getTenantsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No tenants found'));
                      }

                      final tenants = snapshot.data!.docs;
                      final filteredTenants = _filterTenants(tenants);

                      return ListView.builder(
                        itemCount: filteredTenants.length,
                        itemBuilder: (context, index) {
                          final tenant = filteredTenants[index];
                          final data = tenant.data() as Map<String, dynamic>;
                          
                          return _buildTenantRow(tenant.id, data);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoveInOutTab() {
    return Column(
      children: [
        // Header with Move In/Out buttons
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Move In/Out Process',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Manage tenant transitions',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showMoveInDialog(),
                    icon: const Icon(Icons.home),
                    label: const Text('Move In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showMoveOutDialog(),
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Move Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Move In/Out Table
        Expanded(
          child: Container(
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
                      Expanded(flex: 2, child: Text('Tenant', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                // Sample Move In/Out Data
                Expanded(
                  child: ListView(
                    children: [
                      _buildMoveInOutRow('Sarah Wilson', 'D-102', 'Move In', '2024-02-01', 'Pending'),
                      _buildMoveInOutRow('Robert Brown', 'A-205', 'Move Out', '2024-01-28', 'Completed'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTenantRow(String tenantId, Map<String, dynamic> data) {
    final balance = data['balance'] ?? 0.0;
    final status = data['status'] ?? 'Current';
    
    Color statusColor = Colors.green;
    if (status == 'Arrears') statusColor = Colors.red;
    if (status == 'Good Standing') statusColor = Colors.blue;
    if (status == 'Vacated') statusColor = Colors.grey;
    
    Color balanceColor = balance >= 0 ? Colors.green : Colors.red;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(data['name'] ?? 'Unknown')),
          Expanded(flex: 1, child: Text(data['unit'] ?? 'N/A')),
          Expanded(flex: 2, child: Text(data['phone'] ?? 'N/A')),
          Expanded(flex: 2, child: Text(data['email'] ?? 'N/A')),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'KES ${balance.toStringAsFixed(0)}',
              style: TextStyle(
                color: balanceColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: PopupMenuButton<String>(
              onSelected: (value) => _handleTenantAction(tenantId, value),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'view', child: Text('View')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveInOutRow(String tenant, String unit, String type, String date, String status) {
    Color statusColor = status == 'Completed' ? Colors.green : Colors.orange;
    Color typeColor = type == 'Move In' ? Colors.orange : Colors.grey;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(tenant)),
          Expanded(flex: 1, child: Text(unit)),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                type,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(flex: 2, child: Text(date)),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text('View Details', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getTenantsStream() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) async* {
      if (user != null) {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final userData = userDoc.data();
          final rentalName = userData?['rental'] as String?;
          
          if (rentalName != null && rentalName.isNotEmpty) {
            yield* FirebaseFirestore.instance
                .collection('rentals')
                .doc(rentalName)
                .collection('tenants')
                .orderBy('createdAt', descending: true)
                .snapshots();
          } else {
            yield* Stream.value(
              await FirebaseFirestore.instance.collection('empty').limit(0).get()
            );
          }
        } catch (e) {
          yield* Stream.value(
            await FirebaseFirestore.instance.collection('empty').limit(0).get()
          );
        }
      } else {
        yield* Stream.value(
          await FirebaseFirestore.instance.collection('empty').limit(0).get()
        );
      }
    });
  }

  List<QueryDocumentSnapshot> _filterTenants(List<QueryDocumentSnapshot> tenants) {
    if (_searchController.text.isEmpty) return tenants;
    
    final searchTerm = _searchController.text.toLowerCase();
    return tenants.where((tenant) {
      final data = tenant.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final unit = (data['unit'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      
      return name.contains(searchTerm) || unit.contains(searchTerm) || email.contains(searchTerm);
    }).toList();
  }

  void _showAddTenantDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddTenantDialog(),
    );
  }

  void _showMoveInDialog() {
    showDialog(
      context: context,
      builder: (context) => const MoveInDialog(),
    );
  }

  void _showMoveOutDialog() {
    showDialog(
      context: context,
      builder: (context) => const MoveOutDialog(),
    );
  }

  void _handleTenantAction(String tenantId, String action) {
    switch (action) {
      case 'view':
        // TODO: Show tenant details
        break;
      case 'edit':
        // TODO: Edit tenant
        break;
      case 'delete':
        _showDeleteTenantConfirmation(tenantId);
        break;
    }
  }

  void _showDeleteTenantConfirmation(String tenantId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tenant'),
        content: const Text('Are you sure you want to delete this tenant? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                  final userData = userDoc.data();
                  final rentalName = userData?['rental'] as String?;
                  
                  if (rentalName != null && rentalName.isNotEmpty) {
                    await FirebaseFirestore.instance
                        .collection('rentals')
                        .doc(rentalName)
                        .collection('tenants')
                        .doc(tenantId)
                        .delete();
                    
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tenant deleted successfully'), backgroundColor: Colors.green),
                    );
                  }
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class UnitManagementPage extends StatelessWidget {
  const UnitManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unit Management'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(child: Text('Unit Management - Coming Soon')),
    );
  }
}

class SMSCommunicationsPage extends StatelessWidget {
  const SMSCommunicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Communications'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(child: Text('SMS Communications - Coming Soon')),
    );
  }
}

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(child: Text('Expenses - Coming Soon')),
    );
  }
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(child: Text('Reports - Coming Soon')),
    );
  }
}

// Add Tenant Dialog
class AddTenantDialog extends StatefulWidget {
  const AddTenantDialog({super.key});

  @override
  State<AddTenantDialog> createState() => _AddTenantDialogState();
}

class _AddTenantDialogState extends State<AddTenantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _unitController = TextEditingController();
  final _balanceController = TextEditingController();
  String _selectedStatus = 'Current';
  bool _isLoading = false;

  final List<String> _statusOptions = ['Current', 'Arrears', 'Good Standing', 'Vacated'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _unitController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.person_add, color: Colors.orange),
          SizedBox(width: 8),
          Text('Add New Tenant'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Please enter tenant name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter email';
                  if (!value!.contains('@')) return 'Please enter valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty ?? true ? 'Please enter phone number' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(
                  labelText: 'Unit *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.home),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Please enter unit' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _balanceController,
                decoration: const InputDecoration(
                  labelText: 'Balance (KES)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.money),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isNotEmpty ?? false) {
                    if (double.tryParse(value!) == null) return 'Please enter valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info),
                ),
                items: _statusOptions.map((status) {
                  return DropdownMenuItem(value: status, child: Text(status));
                }).toList(),
                onChanged: (value) => setState(() => _selectedStatus = value!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addTenant,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : const Text('Add Tenant'),
        ),
      ],
    );
  }

  void _addTenant() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final userData = userDoc.data();
          final rentalName = userData?['rental'] as String?;
          
          if (rentalName != null && rentalName.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('rentals')
                .doc(rentalName)
                .collection('tenants')
                .add({
              'name': _nameController.text.trim(),
              'email': _emailController.text.trim(),
              'phone': _phoneController.text.trim(),
              'unit': _unitController.text.trim(),
              'balance': _balanceController.text.isEmpty ? 0.0 : double.parse(_balanceController.text.trim()),
              'status': _selectedStatus,
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': user.uid,
              'rentalName': rentalName,
            });

            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tenant added successfully!'), backgroundColor: Colors.green),
            );
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
}

// Move In Dialog
class MoveInDialog extends StatefulWidget {
  const MoveInDialog({super.key});

  @override
  State<MoveInDialog> createState() => _MoveInDialogState();
}

class _MoveInDialogState extends State<MoveInDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tenantController = TextEditingController();
  final _unitController = TextEditingController();
  final _dateController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateTime.now().toString().split(' ')[0];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.home, color: Colors.orange),
          SizedBox(width: 8),
          Text('Move In Process'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _tenantController,
              decoration: const InputDecoration(
                labelText: 'Tenant Name *',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Please enter tenant name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: 'Unit *',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Please enter unit' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Move In Date *',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  _dateController.text = date.toString().split(' ')[0];
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _processMoveIn,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : const Text('Process Move In'),
        ),
      ],
    );
  }

  void _processMoveIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final userData = userDoc.data();
          final rentalName = userData?['rental'] as String?;
          
          if (rentalName != null && rentalName.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('rentals')
                .doc(rentalName)
                .collection('moveInOut')
                .add({
              'tenantName': _tenantController.text.trim(),
              'unit': _unitController.text.trim(),
              'type': 'Move In',
              'date': _dateController.text,
              'status': 'Pending',
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': user.uid,
            });

            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Move in process initiated!'), backgroundColor: Colors.green),
            );
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
}

// Move Out Dialog
class MoveOutDialog extends StatefulWidget {
  const MoveOutDialog({super.key});

  @override
  State<MoveOutDialog> createState() => _MoveOutDialogState();
}

class _MoveOutDialogState extends State<MoveOutDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tenantController = TextEditingController();
  final _unitController = TextEditingController();
  final _dateController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateTime.now().toString().split(' ')[0];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.exit_to_app, color: Colors.grey),
          SizedBox(width: 8),
          Text('Move Out Process'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _tenantController,
              decoration: const InputDecoration(
                labelText: 'Tenant Name *',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Please enter tenant name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: 'Unit *',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Please enter unit' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Move Out Date *',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  _dateController.text = date.toString().split(' ')[0];
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _processMoveOut,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : const Text('Process Move Out'),
        ),
      ],
    );
  }

  void _processMoveOut() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final userData = userDoc.data();
          final rentalName = userData?['rental'] as String?;
          
          if (rentalName != null && rentalName.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('rentals')
                .doc(rentalName)
                .collection('moveInOut')
                .add({
              'tenantName': _tenantController.text.trim(),
              'unit': _unitController.text.trim(),
              'type': 'Move Out',
              'date': _dateController.text,
              'status': 'Pending',
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': user.uid,
            });

            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Move out process initiated!'), backgroundColor: Colors.green),
            );
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
}