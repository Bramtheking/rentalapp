import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import '../services/auth_service.dart';
import '../services/dashboard_service.dart';
import '../services/sms_service.dart';
import '../services/payment_tracking_service.dart';
import '../services/receipt_service.dart';
import '../models/sms_format_model.dart';
import 'super_admin_dashboard.dart';
import 'tenants_screen.dart';
import 'units_screen.dart';
import 'sms_screen.dart';
import 'expenses_screen.dart';
import 'reports_screen.dart';
import 'payment_structure_screen.dart';
import 'unit_approval_screen.dart';
import 'penalty_calculator_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _selectedBuildingId;
  String _selectedBuildingName = 'Select Building';
  List<Map<String, dynamic>> _userBuildings = [];
  bool _isLoadingBuildings = true;
  String? _userRole;
  bool _canCreateBuildings = false;
  Timer? _autoSyncTimer;

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
  void initState() {
    super.initState();
    _loadBuildingSelectionFirst();
    _startAutoSync();
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBuildingSelectionFirst() async {
    // First, try to restore building selection from local storage
    await _restoreBuildingSelectionFromStorage();
    // Then load user data and buildings
    await _loadUserData();
  }

  Future<void> _restoreBuildingSelectionFromStorage() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? lastSelectedId = prefs.getString('selected_building_id');
      String? lastSelectedName = prefs.getString('selected_building_name');
      int? lastSelectedTab = prefs.getInt('selected_tab_index');
      
      setState(() {
        if (lastSelectedId != null && lastSelectedName != null) {
          _selectedBuildingId = lastSelectedId;
          _selectedBuildingName = lastSelectedName;
        }
        if (lastSelectedTab != null) {
          _selectedIndex = lastSelectedTab;
        }
      });
    } catch (e) {
      print('Error restoring building selection from storage: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only restore if we truly have no selection and have buildings loaded
    if (_selectedBuildingId == null && _userBuildings.isNotEmpty) {
      _restoreBuildingSelection();
    }
  }

  Future<void> _restoreBuildingSelection() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? lastSelectedId = prefs.getString('selected_building_id');
      String? lastSelectedName = prefs.getString('selected_building_name');
      
      if (lastSelectedId != null && _userBuildings.any((b) => b['id'] == lastSelectedId)) {
        setState(() {
          _selectedBuildingId = lastSelectedId;
          _selectedBuildingName = lastSelectedName ?? 'Select Building';
        });
      } else if (_userBuildings.isNotEmpty && _selectedBuildingId == null) {
        // Only fallback to first building if no building is currently selected
        setState(() {
          _selectedBuildingId = _userBuildings.first['id'];
          _selectedBuildingName = _userBuildings.first['name'];
        });
        // Save the fallback selection
        _saveBuildingSelection(_userBuildings.first['id'], _userBuildings.first['name']);
      }
    } catch (e) {
      print('Error restoring building selection: $e');
    }
  }

  Future<void> _saveBuildingSelection(String? buildingId, String buildingName) async {
    if (buildingId == null) return;
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_building_id', buildingId);
      await prefs.setString('selected_building_name', buildingName);
    } catch (e) {
      print('Error saving building selection: $e');
    }
  }

  Future<void> _saveSelectedTab(int tabIndex) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_tab_index', tabIndex);
    } catch (e) {
      print('Error saving selected tab: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get user role first
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return;

      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null) return;

      setState(() {
        _userRole = userData['userType'] ?? 'rentalmanager';
        _canCreateBuildings = _userRole == 'rentalmanager' || _userRole == 'superadmin';
      });

      // Load buildings based on role
      await _loadUserBuildings();

    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoadingBuildings = false;
      });
    }
  }

  Future<void> _loadUserBuildings() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get user document to find their buildings
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return;

      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null) return;

      List<Map<String, dynamic>> buildings = [];

      // Load buildings based on user role
      if (_userRole == 'rentalmanager' || _userRole == 'superadmin') {
        // Rental managers and superadmins can see buildings they created
        
        // Check if user has buildings array (new system)
        if (userData['buildings'] != null) {
          List<String> buildingIds = List<String>.from(userData['buildings']);
          
          for (String buildingId in buildingIds) {
            DocumentSnapshot buildingDoc = await FirebaseFirestore.instance
                .collection('rentals')
                .doc(buildingId)
                .get();
            
            if (buildingDoc.exists) {
              Map<String, dynamic> buildingData = buildingDoc.data() as Map<String, dynamic>;
              buildings.add({
                'id': buildingId,
                'name': buildingData['name'] ?? 'Unnamed Building',
                'address': buildingData['address'] ?? '',
                'totalUnits': buildingData['totalUnits'] ?? 0,
                'isActive': buildingData['isActive'] ?? true,
              });
            }
          }
        } else {
          // Fallback: Query buildings created by this user
          QuerySnapshot buildingQuery = await FirebaseFirestore.instance
              .collection('rentals')
              .where('createdBy', isEqualTo: currentUser.uid)
              .where('isActive', isEqualTo: true)
              .get();
          
          for (DocumentSnapshot buildingDoc in buildingQuery.docs) {
            Map<String, dynamic> buildingData = buildingDoc.data() as Map<String, dynamic>;
            buildings.add({
              'id': buildingDoc.id,
              'name': buildingData['name'] ?? 'Unnamed Building',
              'address': buildingData['address'] ?? '',
              'totalUnits': buildingData['totalUnits'] ?? 0,
              'isActive': buildingData['isActive'] ?? true,
            });
          }
        }
        
      } else if (_userRole == 'editor') {
        // Editors can only access buildings assigned to them via the rental field
        if (userData['rental'] != null && userData['rental'].toString().isNotEmpty) {
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
              'address': buildingData['address'] ?? '',
              'totalUnits': buildingData['totalUnits'] ?? 0,
              'isActive': buildingData['isActive'] ?? true,
            });
          }
        }
        
        // Also check if editor has specific buildings assigned via buildings array
        if (userData['buildings'] != null) {
          List<String> buildingIds = List<String>.from(userData['buildings']);
          
          for (String buildingId in buildingIds) {
            DocumentSnapshot buildingDoc = await FirebaseFirestore.instance
                .collection('rentals')
                .doc(buildingId)
                .get();
            
            if (buildingDoc.exists) {
              Map<String, dynamic> buildingData = buildingDoc.data() as Map<String, dynamic>;
              // Avoid duplicates
              if (!buildings.any((b) => b['id'] == buildingId)) {
                buildings.add({
                  'id': buildingId,
                  'name': buildingData['name'] ?? 'Unnamed Building',
                  'address': buildingData['address'] ?? '',
                  'totalUnits': buildingData['totalUnits'] ?? 0,
                  'isActive': buildingData['isActive'] ?? true,
                });
              }
            }
          }
        }
      }

      setState(() {
        _userBuildings = buildings;
        _isLoadingBuildings = false;
        
        // Auto-select the last selected building or first available building
        if (buildings.isNotEmpty) {
          String? lastSelectedId = userData['lastSelectedBuilding'];
          if (lastSelectedId != null && buildings.any((b) => b['id'] == lastSelectedId)) {
            _selectedBuildingId = lastSelectedId;
            _selectedBuildingName = buildings.firstWhere((b) => b['id'] == lastSelectedId)['name'];
          } else {
            _selectedBuildingId = buildings.first['id'];
            _selectedBuildingName = buildings.first['name'];
          }
        }
      });

    } catch (e) {
      print('Error loading user buildings: $e');
      setState(() {
        _isLoadingBuildings = false;
      });
    }
  }

  void _startAutoSync() {
    // Start auto-sync timer for every 2 minutes
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _performAutoSync();
    });
  }

  Future<void> _performAutoSync() async {
    // Only auto-sync if we have a selected building and user is not actively using the app
    if (_selectedBuildingId == null) return;
    
    try {
      // Check if building has SMS sender configured
      final SMSService smsService = SMSService();
      
      // Skip auto-sync if platform doesn't support it
      if (!smsService.canSync()) return;
      
      String? smsSender = await smsService.getBuildingSMSSender(_selectedBuildingId!);
      
      if (smsSender == null) return; // No SMS sender configured, skip auto-sync
      
      // Check if auto-sync is enabled for this building
      bool autoSyncEnabled = await smsService.isAutoSyncEnabled(_selectedBuildingId!);
      if (!autoSyncEnabled) return;
      
      // Perform silent SMS sync (limit to recent messages to avoid overwhelming)
      List<SMSTransaction> transactions = await smsService.syncSMSMessages(_selectedBuildingId!);
      
      // Process payments for new transactions
      for (SMSTransaction transaction in transactions) {
        if (transaction.unit.isNotEmpty) {
          try {
            await _processPaymentFromSMS(transaction);
          } catch (e) {
            print('Auto-sync payment processing error: $e');
          }
        }
      }
      
      print('Auto-sync completed: ${transactions.length} transactions processed');
      
    } catch (e) {
      // Silent failure for auto-sync - don't show errors to user
      print('Auto-sync error: $e');
    }
  }

  Future<void> _performSilentSMSSync(SMSService smsService, SMSFormat bankFormat, String bankId) async {
    // This would be where we read actual SMS messages from the device
    // For now, we'll skip the sample data insertion during auto-sync
    // In a real implementation, this would:
    // 1. Read SMS messages from device since last sync
    // 2. Filter by bank format
    // 3. Parse and store new transactions
    // 4. Update sync timestamp
    
    // Get sync start date to avoid processing old messages
    DateTime? syncStartDate = await smsService.getSyncStartDate(_selectedBuildingId!);
    if (syncStartDate == null) {
      // Set default sync start date to current time if not set
      await smsService.setSyncStartDate(_selectedBuildingId!, DateTime.now());
    }
    
    // In a real implementation, we would:
    // - Use platform channels to read SMS messages
    // - Filter messages by date and sender
    // - Parse using the bank format
    // - Store new transactions
    
    print('Auto-sync completed for building: $_selectedBuildingId');
  }

  Future<void> _processPaymentFromSMS(SMSTransaction transaction) async {
    try {
      // Check if unit exists in the system
      final unitsSnapshot = await FirebaseFirestore.instance
          .collection('rentals')
          .doc(transaction.buildingId)
          .collection('units')
          .where('unitNumber', isEqualTo: transaction.unit)
          .limit(1)
          .get();

      if (unitsSnapshot.docs.isNotEmpty) {
        // Unit exists, process payment
        final paymentService = PaymentTrackingService();
        final result = await paymentService.processPayment(
          buildingId: transaction.buildingId,
          unitRef: transaction.unit,
          amount: transaction.amount,
          paymentDate: transaction.date,
          reference: transaction.reference,
          method: 'SMS Auto-Sync',
        );

        // Update transaction status based on payment result
        String status = result.isComplete ? 'matched' : 'partial';
        await FirebaseFirestore.instance
            .collection('rentals')
            .doc(transaction.buildingId)
            .collection('smsTransactions')
            .doc(transaction.id)
            .update({
          'status': status,
          'paymentBreakdown': result.breakdown ?? {},
        });
      }
      // If unit doesn't exist, transaction remains as 'pending' for manual approval
    } catch (e) {
      print('Error processing payment from SMS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _pageNames[_selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        centerTitle: false,
        flexibleSpace: Container(
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
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          if (_selectedBuildingId != null)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _selectedBuildingName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF667eea),
                Color(0xFF764ba2),
                Color(0xFFf093fb),
                Color(0xFFf5576c),
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: Column(
            children: [
              // Header with glassmorphism
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Glassmorphic logo container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.25),
                            Colors.white.withOpacity(0.1),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.business_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'RentManager Pro',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(0.15),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: const Text(
                        'Property Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content Area with glassmorphism
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.25),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Building Status Indicator
                      if (_selectedBuildingId == null)
                        Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.withOpacity(0.1),
                                Colors.red.withOpacity(0.05),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.warning_rounded, 
                                  color: Colors.red[600], 
                                  size: 24
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No Building Selected',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Select a building to access all features',
                                style: TextStyle(
                                  fontSize: 12,
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          children: [
                            _buildModernNavItem(Icons.dashboard_rounded, 'Dashboard', 0),
                            _buildModernNavItem(Icons.payment_rounded, 'Rent Payments', 1),
                            _buildModernNavItem(Icons.people_rounded, 'Tenant Management', 2),
                            _buildModernNavItem(Icons.home_work_rounded, 'Unit Management', 3),
                            _buildModernNavItem(Icons.sms_rounded, 'SMS Communications', 4),
                            _buildModernNavItem(Icons.receipt_long_rounded, 'Expenses', 5),
                            _buildModernNavItem(Icons.analytics_rounded, 'Reports', 6),
                            const SizedBox(height: 16),
                            Container(
                              height: 1,
                              color: Colors.grey[200],
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            const SizedBox(height: 16),
                            _buildModernNavItem(Icons.person_rounded, 'Profile', 7),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8F9FA),
              Color(0xFFE9ECEF),
              Color(0xFFF8F9FA),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.7),
                Colors.white.withOpacity(0.3),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: _buildMainContent(),
          ),
        ),
      ),
      floatingActionButton: _selectedIndex == 0 && _selectedBuildingId != null
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF667eea),
                    Color(0xFF764ba2),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667eea).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(-2, -2),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: () => _showQuickActions(context),
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: const Icon(
                  Icons.add_rounded, 
                  color: Colors.white,
                  size: 28,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildModernNavItem(IconData icon, String title, int index) {
    final isSelected = _selectedIndex == index;
    final requiresBuilding = _requiresBuilding(index);
    final isDisabled = requiresBuilding && _selectedBuildingId == null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isDisabled 
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please select a building first from the Dashboard'),
                      backgroundColor: const Color(0xFF667eea),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              : () {
                  setState(() {
                    _selectedIndex = index;
                  });
                  _saveSelectedTab(index);
                  Navigator.pop(context); // Close the drawer
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: isSelected 
                  ? LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.1),
                      ],
                    )
                  : null,
              border: isSelected 
                  ? Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    )
                  : null,
              boxShadow: isSelected 
                  ? [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: isDisabled 
                          ? [
                              Colors.grey.withOpacity(0.1),
                              Colors.grey.withOpacity(0.05),
                            ]
                          : isSelected 
                              ? [
                                  Colors.white.withOpacity(0.4),
                                  Colors.white.withOpacity(0.2),
                                ]
                              : [
                                  Colors.white.withOpacity(0.2),
                                  Colors.white.withOpacity(0.1),
                                ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: isDisabled 
                        ? Colors.white.withOpacity(0.4)
                        : Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isDisabled 
                          ? Colors.white.withOpacity(0.4)
                          : Colors.white,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (isDisabled)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                if (isSelected)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Keep the old method for compatibility
  Widget _buildNavItem(IconData icon, String title, int index) {
    return _buildModernNavItem(icon, title, index);
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
          canCreateBuildings: _canCreateBuildings,
          onBuildingChanged: (id, name) {
            setState(() {
              _selectedBuildingId = id;
              _selectedBuildingName = name;
            });
            _saveBuildingSelection(id, name);
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
          canCreateBuildings: _canCreateBuildings,
          onBuildingChanged: (id, name) {
            setState(() {
              _selectedBuildingId = id;
              _selectedBuildingName = name;
            });
            _saveBuildingSelection(id, name);
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
                color: const Color(0xFF667eea).withOpacity(0.6),
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
                      _saveSelectedTab(0);
                    },
                    icon: const Icon(Icons.dashboard),
                    label: const Text('Go to Dashboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_canCreateBuildings)
                    OutlinedButton.icon(
                      onPressed: () => _showAddBuildingDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Building'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF667eea),
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

  void _showAddBuildingDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AddBuildingDialog(),
    );
    
    // If building was created successfully, refresh the building list
    if (result == true) {
      _loadUserData(); // Refresh user data and buildings
    }
  }

  void _showQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.95),
              Colors.white.withOpacity(0.85),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar with glassmorphism
            Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.withOpacity(0.3),
                    Colors.grey.withOpacity(0.1),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Title with glassmorphic background
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF667eea).withOpacity(0.1),
                    const Color(0xFF764ba2).withOpacity(0.05),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFF667eea).withOpacity(0.2),
                ),
              ),
              child: const Text(
                '⚡ Quick Actions',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildQuickActionCard(
                    Icons.people_rounded,
                    'Tenants',
                    const Color(0xFF667eea),
                    () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedIndex = 2;
                      });
                      _saveSelectedTab(2);
                    },
                  ),
                  _buildQuickActionCard(
                    Icons.home_work_rounded,
                    'Units',
                    const Color(0xFF764ba2),
                    () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedIndex = 3;
                      });
                      _saveSelectedTab(3);
                    },
                  ),
                  _buildQuickActionCard(
                    Icons.sms_rounded,
                    'SMS',
                    const Color(0xFFf093fb),
                    () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedIndex = 4;
                      });
                      _saveSelectedTab(4);
                    },
                  ),
                  _buildQuickActionCard(
                    Icons.analytics_rounded,
                    'Reports',
                    const Color(0xFFf5576c),
                    () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedIndex = 6;
                      });
                      _saveSelectedTab(6);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.15),
                color.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  final String? selectedBuildingId;
  final String selectedBuildingName;
  final bool canCreateBuildings;
  final Function(String?, String) onBuildingChanged;
  final VoidCallback onAddBuilding;

  const DashboardPage({
    super.key,
    required this.selectedBuildingId,
    required this.selectedBuildingName,
    required this.canCreateBuildings,
    required this.onBuildingChanged,
    required this.onAddBuilding,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DashboardService _dashboardService = DashboardService();
  
  // Separate loading states for different sections
  Map<String, dynamic> dashboardData = {};
  List<Map<String, dynamic>> monthlyTrends = [];
  Map<String, dynamic> unitsData = {};
  Map<String, dynamic> tenantsData = {};
  Map<String, dynamic> financialData = {};
  
  bool isLoadingFinancial = false;
  bool isLoadingCharts = false;
  bool isLoadingUnits = false;
  bool isLoadingTenants = false;

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
        // Reset all data and start loading
        setState(() {
          dashboardData = {};
          monthlyTrends = [];
          unitsData = {};
          tenantsData = {};
          financialData = {};
          isLoadingFinancial = false;
          isLoadingCharts = false;
          isLoadingUnits = false;
          isLoadingTenants = false;
        });
        _loadDashboardData();
      } else {
        setState(() {
          dashboardData = {};
          monthlyTrends = [];
          unitsData = {};
          tenantsData = {};
          financialData = {};
          isLoadingFinancial = false;
          isLoadingCharts = false;
          isLoadingUnits = false;
          isLoadingTenants = false;
        });
      }
    }
  }

  Future<void> _loadDashboardData() async {
    if (widget.selectedBuildingId == null) return;
    
    // Load different sections independently for faster UI
    _loadUnitsData();
    _loadTenantsData();
    _loadFinancialData();
    _loadChartsData();
  }

  Future<void> _loadUnitsData() async {
    if (widget.selectedBuildingId == null) return;
    
    setState(() {
      isLoadingUnits = true;
    });

    try {
      final data = await _dashboardService.getUnitsData(widget.selectedBuildingId!);
      setState(() {
        unitsData = data;
        isLoadingUnits = false;
      });
    } catch (e) {
      setState(() {
        isLoadingUnits = false;
      });
    }
  }

  Future<void> _loadTenantsData() async {
    if (widget.selectedBuildingId == null) return;
    
    setState(() {
      isLoadingTenants = true;
    });

    try {
      final data = await _dashboardService.getTenantsData(widget.selectedBuildingId!);
      setState(() {
        tenantsData = data;
        isLoadingTenants = false;
      });
    } catch (e) {
      setState(() {
        isLoadingTenants = false;
      });
    }
  }

  Future<void> _loadFinancialData() async {
    if (widget.selectedBuildingId == null) return;
    
    setState(() {
      isLoadingFinancial = true;
    });

    try {
      final payments = await _dashboardService.getPaymentsData(widget.selectedBuildingId!);
      final expenses = await _dashboardService.getExpensesData(widget.selectedBuildingId!);
      
      final totalIncome = payments['totalIncome'] ?? 0.0;
      final totalExpenses = expenses['totalExpenses'] ?? 0.0;
      final netProfit = totalIncome - totalExpenses;
      
      setState(() {
        financialData = {
          'totalIncome': totalIncome,
          'totalExpenses': totalExpenses,
          'netProfit': netProfit,
          'payments': payments,
          'expenses': expenses,
        };
        isLoadingFinancial = false;
      });
    } catch (e) {
      setState(() {
        isLoadingFinancial = false;
      });
    }
  }

  Future<void> _loadChartsData() async {
    if (widget.selectedBuildingId == null) return;
    
    setState(() {
      isLoadingCharts = true;
    });

    try {
      final trends = await _dashboardService.getMonthlyTrends(widget.selectedBuildingId!);
      setState(() {
        monthlyTrends = trends;
        isLoadingCharts = false;
      });
    } catch (e) {
      setState(() {
        isLoadingCharts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          // Add Building Button (only for rental managers and superadmins)
          if (widget.canCreateBuildings)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: widget.onAddBuilding,
              tooltip: 'Add Building',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: widget.selectedBuildingId != null ? () {
              // Reset and reload all data
              setState(() {
                unitsData = {};
                tenantsData = {};
                financialData = {};
                monthlyTrends = [];
              });
              _loadDashboardData();
            } : null,
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
                            Icon(Icons.admin_panel_settings, color: const Color(0xFF667eea)),
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
                          Icon(Icons.logout, color: const Color(0xFF667eea)),
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
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
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
                    'Manage your property with ease',
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
                      foregroundColor: const Color(0xFF667eea),
                    ),
                    child: const Text('Start Exploring'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Dashboard Content
            if (widget.selectedBuildingId != null) ...[
              // Financial Overview Cards (with loading state)
              _buildFinancialOverview(),
              const SizedBox(height: 24),
              
              // Charts Section (with loading state)
              _buildChartsSection(),
              const SizedBox(height: 24),
              
              // Property Statistics (loads independently)
              _buildPropertyStatistics(),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.business,
                      size: 64,
                      color: const Color(0xFF667eea),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Get Started with Your First Building',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF667eea),
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
                    if (widget.canCreateBuildings)
                      ElevatedButton.icon(
                        onPressed: widget.onAddBuilding,
                        icon: const Icon(Icons.add),
                        label: const Text('Create Your First Building'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
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
            ? const Color(0xFF667eea).withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasBuilding 
              ? const Color(0xFF667eea).withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
          width: hasBuilding ? 1 : 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasBuilding ? Icons.business : Icons.warning,
            color: hasBuilding ? const Color(0xFF667eea) : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rentals')
                  .where('createdBy', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('Loading your buildings...');
                }

                final buildings = snapshot.data!.docs;
                
                if (buildings.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No buildings found',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create your first building to get started',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  );
                }
                
                // Check if selectedBuildingId exists in the buildings list
                bool buildingExists = buildings.any((doc) => doc.id == widget.selectedBuildingId);
                String? safeSelectedId = buildingExists ? widget.selectedBuildingId : null;
                
                return DropdownButton<String>(
                  value: safeSelectedId,
                  hint: const Text('Select Building'),
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          constraints: const BoxConstraints(maxHeight: 60),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                data['name'] ?? 'Unnamed Building',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              if (data['address'] != null && data['address'].toString().isNotEmpty)
                                Flexible(
                                  child: Text(
                                    data['address'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              Text(
                                '${data['totalUnits'] ?? 0} units',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) async {
                    String newName = 'Select Building';
                    if (value != null) {
                      final building = buildings.firstWhere((doc) => doc.id == value);
                      final data = building.data() as Map<String, dynamic>;
                      newName = data['name'] ?? 'Unnamed Building';
                      
                      // Update user's last selected building in Firestore
                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser?.uid)
                            .update({
                          'lastSelectedBuilding': value,
                          'lastSelectedBuildingName': newName,
                          'rental': newName, // Keep backward compatibility
                        });
                      } catch (e) {
                        print('Error updating last selected building: $e');
                      }
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
              icon: const Icon(Icons.more_vert, color: const Color(0xFF667eea)),
              onSelected: (value) => _handleBuildingAction(value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: const Color(0xFF667eea)),
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
              child: isLoadingFinancial 
                  ? _buildSkeletonCard()
                  : _buildMetricCard(
                      'Total Income',
                      'KES ${_formatCurrency(financialData['totalIncome'] ?? 0)}',
                      Icons.trending_up,
                      Colors.green,
                      subtitle: financialData['payments']?['growthRate'] != null 
                          ? '${financialData['payments']['growthRate'].toStringAsFixed(1)}% vs last month'
                          : null,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isLoadingFinancial 
                  ? _buildSkeletonCard()
                  : _buildMetricCard(
                      'Total Expenses',
                      'KES ${_formatCurrency(financialData['totalExpenses'] ?? 0)}',
                      Icons.trending_down,
                      Colors.red,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isLoadingFinancial 
                  ? _buildSkeletonCard()
                  : _buildMetricCard(
                      'Net Profit',
                      'KES ${_formatCurrency(financialData['netProfit'] ?? 0)}',
                      Icons.account_balance_wallet,
                      const Color(0xFF764ba2),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isLoadingUnits 
                  ? _buildSkeletonCard()
                  : _buildMetricCard(
                      'Occupancy Rate',
                      '${(unitsData['occupancyRate'] ?? 0).toStringAsFixed(1)}%',
                      Icons.home,
                      const Color(0xFF667eea),
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
                    Expanded(
                      child: isLoadingCharts 
                          ? _buildChartSkeleton()
                          : _buildMonthlyTrendsChart(),
                    ),
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
                    Expanded(
                      child: isLoadingUnits 
                          ? _buildChartSkeleton()
                          : _buildOccupancyChart(),
                    ),
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
              child: isLoadingUnits 
                  ? _buildSkeletonCard()
                  : _buildStatCard(
                      'Total Units',
                      '${unitsData['totalUnits'] ?? 0}',
                      Icons.home_work,
                      const Color(0xFF764ba2),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isLoadingTenants 
                  ? _buildSkeletonCard()
                  : _buildStatCard(
                      'Active Tenants',
                      '${tenantsData['activeTenants'] ?? 0}',
                      Icons.people,
                      Colors.green,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isLoadingFinancial 
                  ? _buildSkeletonCard()
                  : _buildStatCard(
                      'Payments This Month',
                      '${financialData['payments']?['paymentsCount'] ?? 0}',
                      Icons.payment,
                      const Color(0xFF667eea),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isLoadingFinancial 
                  ? _buildSkeletonCard()
                  : _buildStatCard(
                      'Expenses This Month',
                      '${financialData['expenses']?['expensesCount'] ?? 0}',
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
                icon: Icons.payment_rounded,
                title: 'Payment Structure',
                onTap: () {
                  if (widget.selectedBuildingId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentStructureScreen(
                          buildingId: widget.selectedBuildingId!,
                          buildingName: widget.selectedBuildingName,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.sync_rounded,
                title: 'Sync Settings',
                onTap: () {
                  _showSyncSettingsDialog();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.approval_rounded,
                title: 'Unit Approval',
                onTap: () {
                  if (widget.selectedBuildingId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UnitApprovalScreen(
                          buildingId: widget.selectedBuildingId!,
                          buildingName: widget.selectedBuildingName,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.calculate_rounded,
                title: 'Penalty Calculator',
                onTap: () {
                  if (widget.selectedBuildingId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PenaltyCalculatorScreen(
                          buildingId: widget.selectedBuildingId!,
                          buildingName: widget.selectedBuildingName,
                        ),
                      ),
                    );
                  }
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
                        color: const Color(0xFF764ba2),
                        startAngle: (occupied / total) * 2 * 3.14159,
                      ),
                    ),
                  // Maintenance arc
                  if (maintenance > 0)
                    CustomPaint(
                      size: const Size(120, 120),
                      painter: ArcPainter(
                        percentage: maintenance / total,
                        color: const Color(0xFF667eea),
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
              _buildOccupancyLegend('Vacant', vacant, const Color(0xFF764ba2)),
            if (maintenance > 0)
              _buildOccupancyLegend('Maintenance', maintenance, const Color(0xFF667eea)),
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
          color: const Color(0xFF667eea).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: const Color(0xFF667eea),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF667eea),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSyncSettingsDialog() async {
    if (widget.selectedBuildingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a building first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final SMSService smsService = SMSService();
      DateTime? currentStartDate = await smsService.getSyncStartDate(widget.selectedBuildingId!);
      
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            DateTime selectedDate = currentStartDate ?? DateTime.now();
            
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.sync_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sync Settings'),
                        Text(
                          'Configure SMS sync options',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SMS Sync Start Date:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose from which date to start syncing SMS messages. This helps avoid processing old messages.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Start Date:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
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
                            selectedDate = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Change Date'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea).withOpacity(0.1),
                        foregroundColor: const Color(0xFF667eea),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF667eea).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: const Color(0xFF667eea),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'SMS messages before this date will be ignored during sync.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
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
                    try {
                      await smsService.setSyncStartDate(widget.selectedBuildingId!, selectedDate);
                      Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sync start date updated to ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      );
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating sync start date: $e'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Settings'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading sync settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Skeleton loading widgets
  Widget _buildSkeletonCard() {
    return Container(
      height: 120,
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
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 80,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: 120,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 100,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSkeleton() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 100,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
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
              color: const Color(0xFF667eea),
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
              color: const Color(0xFF667eea),
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
              color: const Color(0xFF667eea),
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
          Icon(Icons.business, color: const Color(0xFF667eea)),
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
            backgroundColor: const Color(0xFF667eea),
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
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          throw Exception('User not authenticated');
        }

        // Create the building document
        DocumentReference buildingRef = await FirebaseFirestore.instance.collection('rentals').add({
          'name': _nameController.text.trim(),
          'address': _addressController.text.trim(),
          'totalUnits': int.parse(_totalUnitsController.text.trim()),
          'description': _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'createdBy': currentUser.uid,
          'ownerId': currentUser.uid,
        });

        // Get the building ID
        String buildingId = buildingRef.id;
        String buildingName = _nameController.text.trim();

        // Update user's buildings list
        DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
        
        // Get current user data
        DocumentSnapshot userDoc = await userRef.get();
        Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
        
        List<String> currentBuildings = [];
        if (userData != null && userData['buildings'] != null) {
          currentBuildings = List<String>.from(userData['buildings']);
        }
        
        // Add new building ID to the list
        if (!currentBuildings.contains(buildingId)) {
          currentBuildings.add(buildingId);
        }

        // Update user document with buildings list
        await userRef.update({
          'buildings': currentBuildings,
          'lastSelectedBuilding': buildingId,
          'lastSelectedBuildingName': buildingName,
          // Keep the old rental field for backward compatibility, but update it to the latest building
          'rental': buildingName,
        });

        // Close the dialog and show success message
        if (context.mounted) {
          Navigator.pop(context, true); // Pass true to indicate success
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Building "$buildingName" added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }

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
    _tabController = TabController(length: 3, vsync: this);
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
            Tab(text: 'SMS Transactions'),
            Tab(text: 'Payment Receipts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPaymentsTab(),
          _buildSMSTransactionsTab(),
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
                  backgroundColor: const Color(0xFF667eea),
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
                                      color: data['status'] == 'Completed' ? Colors.green : const Color(0xFF667eea),
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

  Widget _buildSMSTransactionsTab() {
    return Container(
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
                          Icons.sms_rounded,
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
                              'SMS Transactions',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Auto-synced payment messages',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.science_rounded, color: Colors.white),
                              onPressed: () => _showTestModeDialog(),
                              tooltip: 'Test Mode - Custom SMS Sync',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
                              onPressed: () => _clearAllSMSTransactions(),
                              tooltip: 'Clear All SMS Transactions',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.sync_rounded, color: Colors.white),
                              onPressed: () => _syncSMSMessages(),
                              tooltip: 'Sync SMS Messages',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // SMS Sender Configuration
                  Container(
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
                        Icon(Icons.sms_rounded, color: Colors.white.withOpacity(0.8)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SMS Sender Setup',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Configure payment SMS source name/number',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _showBankAssignmentDialog(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Setup'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // SMS Transactions List
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          const Text(
                            'Recent SMS Transactions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const Spacer(),
                          // Real sync status - only show if there's actual data
                          FutureBuilder<DateTime?>(
                            future: widget.selectedBuildingId != null 
                                ? SMSService().getSyncStartDate(widget.selectedBuildingId!)
                                : null,
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                final syncStartDate = snapshot.data!;
                                final now = DateTime.now();
                                final difference = now.difference(syncStartDate);
                                
                                String syncText;
                                if (difference.inDays > 0) {
                                  syncText = 'Sync from ${difference.inDays}d ago';
                                } else if (difference.inHours > 0) {
                                  syncText = 'Sync from ${difference.inHours}h ago';
                                } else if (difference.inMinutes > 0) {
                                  syncText = 'Sync from ${difference.inMinutes}m ago';
                                } else {
                                  syncText = 'Sync configured';
                                }
                                
                                return Text(
                                  syncText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                );
                              }
                              // Don't show anything if sync is not configured
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: widget.selectedBuildingId == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.business_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Select a building to view SMS transactions',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildSMSTransactionsList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSMSTransactionsList() {
    return StreamBuilder<List<SMSTransaction>>(
      stream: _getSMSTransactionsStream(),
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

        final transactions = snapshot.data ?? [];

        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sms_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No SMS transactions found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'SMS messages will appear here after syncing',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final transaction = transactions[index];
            return _buildSMSTransactionCard(transaction);
          },
        );
      },
    );
  }

  Widget _buildSMSTransactionCard(SMSTransaction transaction) {
    Color statusColor = Colors.grey;
    switch (transaction.status) {
      case 'matched':
        statusColor = Colors.green;
        break;
      case 'pending':
        statusColor = const Color(0xFFf093fb);
        break;
      case 'partial':
        statusColor = Colors.orange;
        break;
    }

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
          onTap: () => _showTransactionDetails(transaction),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [statusColor, statusColor.withOpacity(0.7)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'KES',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
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
                            'KES ${transaction.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          Text(
                            '${transaction.building}${transaction.unit}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            transaction.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTransactionDate(transaction.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (transaction.paymentBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Breakdown:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...transaction.paymentBreakdown.entries.map((entry) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                'KES ${entry.value.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTransactionDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }

  Stream<List<SMSTransaction>> _getSMSTransactionsStream() {
    if (widget.selectedBuildingId == null) {
      return Stream.value([]);
    }
    
    return FirebaseFirestore.instance
        .collection('rentals')
        .doc(widget.selectedBuildingId!)
        .collection('smsTransactions')
        .orderBy('date', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => 
            SMSTransaction.fromMap(doc.data(), doc.id)).toList());
  }

  void _syncSMSMessages() async {
    if (widget.selectedBuildingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a building first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading dialog
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
              const Text('Syncing SMS messages...'),
              const SizedBox(height: 8),
              Text(
                'Reading SMS messages from your device',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );

      final SMSService smsService = SMSService();
      
      // Check if platform supports SMS sync
      if (!smsService.canSync()) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(smsService.getSyncStatusMessage()),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Get building's SMS sender configuration
      String? smsSender = await smsService.getBuildingSMSSender(widget.selectedBuildingId!);
      
      if (smsSender == null) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please assign a bank to this building first'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Sync SMS messages from device
      List<SMSTransaction> transactions = await smsService.syncSMSMessages(widget.selectedBuildingId!);
      
      // Process payments for transactions with valid units
      int processedPayments = 0;
      for (SMSTransaction transaction in transactions) {
        if (transaction.unit.isNotEmpty) {
          try {
            await _processPaymentFromSMS(transaction);
            processedPayments++;
          } catch (e) {
            print('Error processing payment for transaction ${transaction.id}: $e');
          }
        }
      }

      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully synced ${transactions.length} SMS transactions${processedPayments > 0 ? ' and processed $processedPayments payments' : ''}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

    } catch (e) {
      Navigator.pop(context); // Close loading dialog if still open
      
      String errorMessage = 'Error syncing SMS: $e';
      if (e.toString().contains('permissions')) {
        errorMessage = 'SMS permissions required. Please grant SMS permissions and try again.';
      } else if (e.toString().contains('No SMS sender configured')) {
        errorMessage = 'Please configure SMS sender for this building first.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  void _clearAllSMSTransactions() async {
    if (widget.selectedBuildingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a building first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Text('Clear All SMS Transactions?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will permanently delete all SMS transactions for this building.'),
            SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
              ),
              SizedBox(height: 16),
              Text('Clearing SMS transactions...'),
            ],
          ),
        ),
      );

      // Get all SMS transactions
      final snapshot = await FirebaseFirestore.instance
          .collection('rentals')
          .doc(widget.selectedBuildingId!)
          .collection('smsTransactions')
          .get();

      // Delete all transactions in batch
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully cleared ${snapshot.docs.length} SMS transactions'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog if still open
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing SMS transactions: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  void _showTestModeDialog() async {
    if (widget.selectedBuildingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a building first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final SMSService smsService = SMSService();
    List<Map<String, String>> availableBanks = smsService.getAvailableBanks();
    
    String? selectedBank;
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.science_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Test Mode'),
                        Text(
                          'Sync from custom phone number',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Test mode allows you to sync SMS from any phone number using a specific bank format.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Enter the phone number that will send test SMS:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'e.g., +254712345678 or TESTBANK',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Select the bank format to use:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedBank,
                      decoration: InputDecoration(
                        labelText: 'Bank Format',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.account_balance),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('-- Select Bank Format --'),
                        ),
                        ...availableBanks.map((bank) {
                          return DropdownMenuItem<String>(
                            value: bank['id'],
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF667eea),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        bank['name']!,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        'Format: ${bank['sender']}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedBank = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF667eea).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: const Color(0xFF667eea),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'How it works:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• Enter any phone number (e.g., your test number)',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Text(
                            '• Select which bank format to parse SMS with',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Text(
                            '• Send SMS from that number in the bank format',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Text(
                            '• Click sync to read and process those SMS',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
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
                  onPressed: (selectedBank == null || phoneController.text.trim().isEmpty) 
                      ? null 
                      : () async {
                    Navigator.pop(context);
                    await _syncSMSInTestMode(
                      phoneController.text.trim(),
                      selectedBank!,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Sync Test SMS'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _syncSMSInTestMode(String phoneNumber, String bankId) async {
    try {
      // Show loading dialog
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
              const Text('Syncing Test SMS...'),
              const SizedBox(height: 8),
              Text(
                'Reading SMS from $phoneNumber',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );

      final SMSService smsService = SMSService();
      
      // Check if platform supports SMS sync
      if (!smsService.canSync()) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(smsService.getSyncStatusMessage()),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Read SMS messages from the specified phone number
      List<SmsMessage> smsMessages = await smsService.readSMSMessages(
        senderFilter: phoneNumber,
        limit: 50,
      );

      List<SMSTransaction> transactions = [];
      
      for (SmsMessage sms in smsMessages) {
        try {
          String smsBody = sms.body ?? '';
          DateTime msgDate = sms.date ?? DateTime.now();

          // Parse SMS using the selected bank format
          Map<String, String> extracted = smsService.parseSMS(smsBody, bankId);
          
          if (extracted.isNotEmpty && 
              extracted.containsKey('amount') && 
              extracted.containsKey('reference')) {
            
            // Extract building and unit from reference
            String reference = extracted['reference'] ?? '';
            String transactionCode = extracted['transactionCode'] ?? reference;
            String referenceType = extracted['referenceType'] ?? 'building_unit';
            Map<String, String> buildingUnit = smsService.extractBuildingAndUnit(reference, referenceType);
            
            // Create SMS transaction
            SMSTransaction transaction = SMSTransaction(
              id: '${msgDate.millisecondsSinceEpoch}_${reference.hashCode}',
              buildingId: widget.selectedBuildingId!,
              amount: double.tryParse(extracted['amount']?.replaceAll(',', '') ?? '0') ?? 0,
              reference: transactionCode,
              building: buildingUnit['building'] ?? '',
              unit: buildingUnit['unit'] ?? '',
              date: msgDate,
              status: 'pending',
              paymentBreakdown: {},
              rawSMS: smsBody,
              bankId: extracted['bank'] ?? bankId,
            );

            // Check if transaction already exists
            bool exists = await _transactionExists(widget.selectedBuildingId!, transaction.id);
            if (!exists) {
              // Save transaction
              await smsService.saveSMSTransaction(widget.selectedBuildingId!, transaction);
              transactions.add(transaction);
              
              // Try to process payment
              if (transaction.unit.isNotEmpty) {
                try {
                  await _processPaymentFromSMS(transaction);
                } catch (e) {
                  print('Error processing payment: $e');
                }
              }
            }
          }
        } catch (e) {
          print('Error processing SMS: $e');
          continue;
        }
      }

      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test Mode: Successfully synced ${transactions.length} SMS transactions from $phoneNumber'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

    } catch (e) {
      Navigator.pop(context); // Close loading dialog if still open
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test Mode Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  Future<bool> _transactionExists(String buildingId, String transactionId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('rentals')
          .doc(buildingId)
          .collection('smsTransactions')
          .doc(transactionId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  Future<void> _processPaymentFromSMS(SMSTransaction transaction) async {
    try {
      // Check if unit exists in the system
      final unitsSnapshot = await FirebaseFirestore.instance
          .collection('rentals')
          .doc(transaction.buildingId)
          .collection('units')
          .where('unitNumber', isEqualTo: transaction.unit)
          .limit(1)
          .get();

      if (unitsSnapshot.docs.isNotEmpty) {
        // Unit exists, process payment
        final paymentService = PaymentTrackingService();
        final result = await paymentService.processPayment(
          buildingId: transaction.buildingId,
          unitRef: transaction.unit,
          amount: transaction.amount,
          paymentDate: transaction.date,
          reference: transaction.reference,
          method: 'SMS Auto-Sync',
        );

        // Update transaction status based on payment result
        String status = result.isComplete ? 'matched' : 'partial';
        await FirebaseFirestore.instance
            .collection('rentals')
            .doc(transaction.buildingId)
            .collection('smsTransactions')
            .doc(transaction.id)
            .update({
          'status': status,
          'paymentBreakdown': result.breakdown ?? {},
        });
      }
      // If unit doesn't exist, transaction remains as 'pending' for manual approval
    } catch (e) {
      print('Error processing payment from SMS: $e');
    }
  }

  void _showBankAssignmentDialog() async {
    if (widget.selectedBuildingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a building first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final SMSService smsService = SMSService();
      
      // Check if platform supports SMS sync
      if (!smsService.canSync()) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('SMS Sync Not Available'),
              ],
            ),
            content: Text(smsService.getSyncStatusMessage()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      
      // Get current bank selection
      String? currentBank = await smsService.getBuildingBank(widget.selectedBuildingId!);
      
      List<Map<String, String>> availableBanks = smsService.getAvailableBanks();
      String? selectedBank = currentBank;
      
      showDialog(
        context: context,
        builder: (dialogContext) {
          // Use a local variable that can be updated
          String? dialogSelectedBank = selectedBank;
          
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.sms_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SMS Sender Setup'),
                          Text(
                            'Configure payment SMS source',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select your bank to enable automatic SMS payment processing:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: dialogSelectedBank,
                        decoration: InputDecoration(
                          labelText: 'Select Bank',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.account_balance),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('-- Select a Bank --'),
                          ),
                          ...availableBanks.map((bank) {
                            return DropdownMenuItem<String>(
                              value: bank['id'],
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF667eea),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          bank['name']!,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          'Sender: ${bank['sender']}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            dialogSelectedBank = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF667eea).withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: const Color(0xFF667eea),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'How it works:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• Select your bank from the list above',
                              style: TextStyle(fontSize: 12),
                            ),
                            const Text(
                              '• The app will read SMS from that bank',
                              style: TextStyle(fontSize: 12),
                            ),
                            const Text(
                              '• Payments will be automatically processed',
                              style: TextStyle(fontSize: 12),
                            ),
                            const Text(
                              '• Your selection is saved and remembered',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
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
                    onPressed: dialogSelectedBank == null ? null : () async {
                      try {
                        // Save the selected bank
                        await smsService.assignBankToBuilding(widget.selectedBuildingId!, dialogSelectedBank!);
                        
                        Navigator.pop(context);
                        
                        // Get bank display name
                        String bankName = availableBanks.firstWhere((b) => b['id'] == dialogSelectedBank)['name']!;
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Bank configured: $bankName'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        );
                      } catch (e) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error configuring bank: $e'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Bank Selection'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading SMS sender dialog: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSyncSettingsDialog() async {
    if (widget.selectedBuildingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a building first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final SMSService smsService = SMSService();
      DateTime? currentStartDate = await smsService.getSyncStartDate(widget.selectedBuildingId!);
      
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            DateTime selectedDate = currentStartDate ?? DateTime.now();
            
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.sync_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sync Settings'),
                        Text(
                          'Configure SMS sync options',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SMS Sync Start Date:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose from which date to start syncing SMS messages. This helps avoid processing old messages.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Start Date:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
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
                            selectedDate = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Change Date'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea).withOpacity(0.1),
                        foregroundColor: const Color(0xFF667eea),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF667eea).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: const Color(0xFF667eea),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'SMS messages before this date will be ignored during sync.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
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
                    try {
                      await smsService.setSyncStartDate(widget.selectedBuildingId!, selectedDate);
                      Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sync start date updated to ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      );
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating sync start date: $e'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Settings'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading sync settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTransactionDetails(SMSTransaction transaction) {
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.sms_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text('SMS Transaction Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Amount', 'KES ${transaction.amount.toStringAsFixed(2)}'),
              _buildDetailRow('Reference', transaction.reference),
              _buildDetailRow('Building', transaction.building),
              _buildDetailRow('Unit', transaction.unit),
              _buildDetailRow('Date', transaction.date.toString().split(' ')[0]),
              _buildDetailRow('Status', transaction.status.toUpperCase()),
              _buildDetailRow('Bank', transaction.bankId.toUpperCase()),
              const SizedBox(height: 12),
              const Text(
                'Raw SMS:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  transaction.rawSMS,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
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
            width: 80,
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
                onPressed: () => _showGenerateReceiptDialog(),
                icon: const Icon(Icons.receipt),
                label: const Text('Generate Receipt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
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
                // Real Receipt Data
                Expanded(
                  child: widget.selectedBuildingId == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.business_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Select a building to view receipts',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : StreamBuilder<QuerySnapshot>(
                          stream: _getReceiptsStream(),
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

                            final receipts = snapshot.data?.docs ?? [];

                            if (receipts.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_outlined,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No receipts found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Generate receipts for payments to see them here',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: receipts.length,
                              itemBuilder: (context, index) {
                                final receipt = receipts[index];
                                final data = receipt.data() as Map<String, dynamic>;
                                
                                return _buildReceiptRowFromData(data);
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
                color: const Color(0xFF667eea),
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
                  onPressed: () => _viewReceipt(receiptNo),
                  child: const Text('View'),
                ),
                TextButton(
                  onPressed: () => _downloadReceipt(receiptNo),
                  child: const Text('Download'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRowFromData(Map<String, dynamic> data) {
    String receiptNo = data['receiptNo'] ?? 'N/A';
    String tenantName = data['tenant']?['name'] ?? 'Unknown';
    String unit = data['tenant']?['unitNumber'] ?? 'N/A';
    String paymentMethod = data['payment']?['method'] ?? 'N/A';
    double amount = (data['payment']?['amount'] ?? 0).toDouble();
    
    DateTime? paymentDate;
    try {
      paymentDate = DateTime.parse(data['date'] ?? '');
    } catch (e) {
      paymentDate = DateTime.now();
    }
    
    String formattedDate = '${paymentDate.day}/${paymentDate.month}/${paymentDate.year}';
    String formattedAmount = 'KES ${amount.toStringAsFixed(0)}';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text(receiptNo, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(flex: 2, child: Text(tenantName)),
          Expanded(flex: 1, child: Text(unit)),
          Expanded(flex: 2, child: Text(formattedDate)),
          Expanded(flex: 2, child: Text(formattedAmount, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text(paymentMethod)),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Generated',
                style: TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                TextButton(
                  onPressed: () => _viewReceipt(receiptNo),
                  child: const Text('View'),
                ),
                TextButton(
                  onPressed: () => _downloadReceipt(receiptNo),
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
    if (widget.selectedBuildingId == null) {
      return Stream.value(FirebaseFirestore.instance.collection('empty').limit(0).get()).asyncMap((future) => future);
    }
    
    return FirebaseFirestore.instance
        .collection('rentals')
        .doc(widget.selectedBuildingId!)
        .collection('payments')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> _getReceiptsStream() {
    if (widget.selectedBuildingId == null) {
      return Stream.value(FirebaseFirestore.instance.collection('empty').limit(0).get()).asyncMap((future) => future);
    }
    
    return FirebaseFirestore.instance
        .collection('rentals')
        .doc(widget.selectedBuildingId!)
        .collection('receipts')
        .orderBy('generatedAt', descending: true)
        .snapshots();
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

  void _showGenerateReceiptDialog() {
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.receipt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Generate Receipt'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a payment to generate receipt:',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'This feature will allow you to:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('• Generate PDF receipts for payments'),
            Text('• Include payment breakdown details'),
            Text('• Add building and tenant information'),
            Text('• Download or print receipts'),
            SizedBox(height: 16),
            Text(
              'Receipt will be generated and copied to clipboard for easy sharing.',
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
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () => _generateSampleReceipt(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
            ),
            child: const Text('Generate Sample Receipt'),
          ),
        ],
      ),
    );
  }

  void _generateSampleReceipt(BuildContext context) async {
    Navigator.pop(context); // Close the dialog first
    
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Generating receipt...'),
            ],
          ),
          backgroundColor: Color(0xFF667eea),
          duration: Duration(seconds: 2),
        ),
      );

      final receiptService = ReceiptService();
      
      // Generate sample receipt
      Map<String, dynamic> receiptData = await receiptService.generateReceipt(
        buildingId: widget.selectedBuildingId!,
        tenantId: 'sample_tenant', // Sample tenant ID
        amount: 15000.0,
        paymentMethod: 'M-PESA',
        paymentDate: DateTime.now(),
        reference: 'SAMPLE123',
        breakdown: {'Rent Payment': 12000.0, 'Water Bill': 2000.0, 'Service Charge': 1000.0},
      );

      // Copy to clipboard
      await receiptService.copyReceiptToClipboard(receiptData);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sample receipt ${receiptData['receiptNo']} generated and copied to clipboard!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () => _showReceiptPreview(receiptData),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating receipt: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  void _generateReceiptForTransaction(SMSTransaction transaction) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Generating receipt...'),
            ],
          ),
          backgroundColor: Color(0xFF667eea),
          duration: Duration(seconds: 2),
        ),
      );

      final receiptService = ReceiptService();
      
      // Generate receipt for actual transaction
      Map<String, dynamic> receiptData = await receiptService.generateReceipt(
        buildingId: widget.selectedBuildingId!,
        tenantId: 'tenant_${transaction.unit}', // Use unit as tenant identifier
        amount: transaction.amount,
        paymentMethod: 'M-PESA',
        paymentDate: transaction.date,
        reference: transaction.reference,
        breakdown: transaction.paymentBreakdown.isNotEmpty 
            ? transaction.paymentBreakdown 
            : {'Rent Payment': transaction.amount},
      );

      // Copy to clipboard
      await receiptService.copyReceiptToClipboard(receiptData);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Receipt ${receiptData['receiptNo']} generated and copied to clipboard!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () => _showReceiptPreview(receiptData),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating receipt: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  void _showReceiptPreview(Map<String, dynamic> receiptData) {
    final receiptService = ReceiptService();
    String receiptText = receiptService.generateReceiptText(receiptData);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt, color: Color(0xFF667eea)),
            const SizedBox(width: 8),
            Text('Receipt ${receiptData['receiptNo']}'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                receiptText,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              await receiptService.copyReceiptToClipboard(receiptData);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Receipt copied to clipboard!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
            ),
            child: const Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  }

  void _viewReceipt(String receiptNo) async {
    try {
      final receiptService = ReceiptService();
      Map<String, dynamic>? receiptData = await receiptService.getReceiptByNumber(
        widget.selectedBuildingId!,
        receiptNo,
      );
      
      if (receiptData != null) {
        _showReceiptPreview(receiptData);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _downloadReceipt(String receiptNo) async {
    try {
      final receiptService = ReceiptService();
      Map<String, dynamic>? receiptData = await receiptService.getReceiptByNumber(
        widget.selectedBuildingId!,
        receiptNo,
      );
      
      if (receiptData != null) {
        await receiptService.copyReceiptToClipboard(receiptData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt $receiptNo copied to clipboard!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => _showReceiptPreview(receiptData),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
          Icon(Icons.payment, color: const Color(0xFF667eea)),
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
                initialValue: _selectedMethod,
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
                initialValue: _selectedStatus,
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
            backgroundColor: const Color(0xFF667eea),
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
          Icon(Icons.edit, color: const Color(0xFF667eea)),
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
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667eea), foregroundColor: Colors.white),
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
              Expanded(child: _buildStatCard('All Tenants', '82', const Color(0xFF667eea), Icons.people)),
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
              Expanded(child: _buildStatCard('Good Standing', '58', const Color(0xFF764ba2), Icons.thumb_up)),
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
                  backgroundColor: const Color(0xFF667eea),
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
                      backgroundColor: const Color(0xFF667eea),
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
    if (status == 'Good Standing') statusColor = const Color(0xFF764ba2);
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
    Color statusColor = status == 'Completed' ? Colors.green : const Color(0xFF667eea);
    Color typeColor = type == 'Move In' ? const Color(0xFF667eea) : Colors.grey;
    
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
            child: Text('View Details', style: TextStyle(color: const Color(0xFF764ba2))),
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
      body: const UnitsScreen(),
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
      body: const SMSScreen(),
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
      body: const ExpensesScreen(),
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
      body: const ReportsScreen(),
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
          Icon(Icons.person_add, color: const Color(0xFF667eea)),
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
                initialValue: _selectedStatus,
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
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667eea), foregroundColor: Colors.white),
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
          Icon(Icons.home, color: const Color(0xFF667eea)),
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
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667eea), foregroundColor: Colors.white),
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
