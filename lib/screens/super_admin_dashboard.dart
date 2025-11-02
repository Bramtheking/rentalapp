import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/rental_model.dart';
import '../utils/firebase_helper.dart';
import '../services/auth_service.dart';
import 'sms_format_editor_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Dashboard'),
        backgroundColor: Colors.orange,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                // Import AuthService
                final authService = AuthService();
                await authService.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              }
            },
            itemBuilder: (BuildContext context) {
              return [
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
              ];
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.home_work), text: 'Rentals'),
            Tab(icon: Icon(Icons.sms), text: 'SMS Formats'),
            Tab(icon: Icon(Icons.add_circle), text: 'Add User'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          UsersManagementTab(),
          RentalsManagementTab(),
          SMSFormatEditorScreen(),
          AddUserTab(),
        ],
      ),
    );
  }
}

// Users Management Tab
class UsersManagementTab extends StatelessWidget {
  const UsersManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No users found'),
          );
        }

        final users = snapshot.data!.docs.map((doc) {
          return UserModel.fromFirestore(doc);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: user.isActive ? Colors.green : Colors.red,
                  child: Text(
                    user.displayName.isNotEmpty 
                        ? user.displayName[0].toUpperCase()
                        : user.email[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(user.displayName.isNotEmpty ? user.displayName : user.email),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email: ${user.email}'),
                    Text('Role: ${user.roleDisplayName}'),
                    if (user.rentalName != null)
                      Text('Rental: ${user.rentalDisplayName}'),
                    Text('Status: ${user.isActive ? "Active" : "Inactive"}'),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => _handleUserAction(context, user, value),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: user.isActive ? 'deactivate' : 'activate',
                      child: Row(
                        children: [
                          Icon(
                            user.isActive ? Icons.block : Icons.check_circle,
                            color: user.isActive ? Colors.red : Colors.green,
                          ),
                          SizedBox(width: 8),
                          Text(user.isActive ? 'Deactivate' : 'Activate'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleUserAction(BuildContext context, UserModel user, String action) {
    switch (action) {
      case 'edit':
        _showEditUserDialog(context, user);
        break;
      case 'activate':
      case 'deactivate':
        _toggleUserStatus(context, user);
        break;
    }
  }

  void _showEditUserDialog(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => EditUserDialog(user: user),
    );
  }

  void _toggleUserStatus(BuildContext context, UserModel user) async {
    try {
      await FirebaseHelper.toggleUserStatus(user.uid, !user.isActive);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ${user.isActive ? 'deactivated' : 'activated'} successfully'),
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
    }
  }
}

// Rentals Management Tab
class RentalsManagementTab extends StatelessWidget {
  const RentalsManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showAddRentalDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Rental Property'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('rentals').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('No rental properties found'),
                );
              }

              final rentals = snapshot.data!.docs.map((doc) {
                return RentalModel.fromFirestore(doc);
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: rentals.length,
                itemBuilder: (context, index) {
                  final rental = rentals[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Icon(Icons.home_work, color: Colors.white),
                      ),
                      title: Text(rental.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Address: ${rental.address}'),
                          Text('Total Units: ${rental.totalUnits}'),
                          if (rental.description != null)
                            Text('Description: ${rental.description}'),
                          Text('Status: ${rental.isActive ? "Active" : "Inactive"}'),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) => _handleRentalAction(context, rental, value),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddRentalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddRentalDialog(),
    );
  }

  void _handleRentalAction(BuildContext context, RentalModel rental, String action) {
    if (action == 'edit') {
      showDialog(
        context: context,
        builder: (context) => EditRentalDialog(rental: rental),
      );
    }
  }
}

// Add User Tab
class AddUserTab extends StatefulWidget {
  const AddUserTab({super.key});

  @override
  State<AddUserTab> createState() => _AddUserTabState();
}

class _AddUserTabState extends State<AddUserTab> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  String _selectedUserType = 'rentalmanager';
  String? _selectedRentalId;
  String? _selectedRentalName;
  bool _isLoading = false;

  final List<String> _userTypes = [
    'rentalmanager',
    'editor',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create New User',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter email';
                }
                if (!value.contains('@')) {
                  return 'Please enter valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedUserType,
              decoration: const InputDecoration(
                labelText: 'User Role',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.admin_panel_settings),
              ),
              items: _userTypes.map((type) {
                String displayName = type == 'rentalmanager' 
                    ? 'Rental Manager' 
                    : 'Editor';
                return DropdownMenuItem(
                  value: type,
                  child: Text(displayName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedUserType = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rentals')
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final rentals = snapshot.data!.docs;
                
                return DropdownButtonFormField<String>(
                  initialValue: _selectedRentalId,
                  decoration: const InputDecoration(
                    labelText: 'Assign Rental Property (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.home_work),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No Rental Assignment'),
                    ),
                    ...rentals.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(data['name'] ?? 'Unknown Rental'),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRentalId = value;
                      if (value != null) {
                        final rental = rentals.firstWhere((doc) => doc.id == value);
                        final data = rental.data() as Map<String, dynamic>;
                        _selectedRentalName = data['name'];
                      } else {
                        _selectedRentalName = null;
                      }
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _createUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Create User',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _createUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await FirebaseHelper.createUserWithRental(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          userType: _selectedUserType,
          displayName: _displayNameController.text.trim().isEmpty 
              ? null 
              : _displayNameController.text.trim(),
          rentalId: _selectedRentalId,
          rentalName: _selectedRentalName,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Clear form
          _emailController.clear();
          _passwordController.clear();
          _displayNameController.clear();
          setState(() {
            _selectedRentalId = null;
            _selectedRentalName = null;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// Edit User Dialog
class EditUserDialog extends StatefulWidget {
  final UserModel user;

  const EditUserDialog({super.key, required this.user});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  late String _selectedUserType;
  String? _selectedRentalId;
  String? _selectedRentalName;

  @override
  void initState() {
    super.initState();
    _selectedUserType = widget.user.userType;
    _selectedRentalId = widget.user.rentalId;
    _selectedRentalName = widget.user.rentalName;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.user.displayName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedUserType,
            decoration: const InputDecoration(
              labelText: 'User Role',
              border: OutlineInputBorder(),
            ),
            items: ['rentalmanager', 'editor'].map((type) {
              String displayName = type == 'rentalmanager' 
                  ? 'Rental Manager' 
                  : 'Editor';
              return DropdownMenuItem(
                value: type,
                child: Text(displayName),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedUserType = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rentals')
                .where('isActive', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }

              final rentals = snapshot.data!.docs;
              
              return DropdownButtonFormField<String>(
                initialValue: _selectedRentalId,
                decoration: const InputDecoration(
                  labelText: 'Rental Assignment',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('No Rental Assignment'),
                  ),
                  ...rentals.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(data['name'] ?? 'Unknown Rental'),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRentalId = value;
                    if (value != null) {
                      final rental = rentals.firstWhere((doc) => doc.id == value);
                      final data = rental.data() as Map<String, dynamic>;
                      _selectedRentalName = data['name'];
                    } else {
                      _selectedRentalName = null;
                    }
                  });
                },
              );
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
          onPressed: _updateUser,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('Update', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _updateUser() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'userType': _selectedUserType,
        'rentalId': _selectedRentalId,
        'rentalName': _selectedRentalName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User updated successfully!'),
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
    }
  }
}

// Add Rental Dialog
class AddRentalDialog extends StatefulWidget {
  const AddRentalDialog({super.key});

  @override
  State<AddRentalDialog> createState() => _AddRentalDialogState();
}

class _AddRentalDialogState extends State<AddRentalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalUnitsController = TextEditingController();

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
      title: const Text('Add New Rental Property'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Rental Property Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter rental property name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
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
                labelText: 'Total Units',
                border: OutlineInputBorder(),
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
              ),
              maxLines: 3,
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
          onPressed: _addRental,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('Add Rental', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _addRental() async {
    if (_formKey.currentState!.validate()) {
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
        });

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rental property added successfully!'),
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
      }
    }
  }
}

// Edit Rental Dialog
class EditRentalDialog extends StatefulWidget {
  final RentalModel rental;

  const EditRentalDialog({super.key, required this.rental});

  @override
  State<EditRentalDialog> createState() => _EditRentalDialogState();
}

class _EditRentalDialogState extends State<EditRentalDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _descriptionController;
  late TextEditingController _totalUnitsController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rental.name);
    _addressController = TextEditingController(text: widget.rental.address);
    _descriptionController = TextEditingController(text: widget.rental.description ?? '');
    _totalUnitsController = TextEditingController(text: widget.rental.totalUnits.toString());
  }

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
      title: const Text('Edit Rental Property'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Rental Property Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter rental property name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
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
                labelText: 'Total Units',
                border: OutlineInputBorder(),
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
              ),
              maxLines: 3,
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
          onPressed: _updateRental,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('Update', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _updateRental() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseFirestore.instance
            .collection('rentals')
            .doc(widget.rental.id)
            .update({
          'name': _nameController.text.trim(),
          'address': _addressController.text.trim(),
          'totalUnits': int.parse(_totalUnitsController.text.trim()),
          'description': _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rental property updated successfully!'),
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
      }
    }
  }
}