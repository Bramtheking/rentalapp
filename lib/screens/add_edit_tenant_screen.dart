import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tenant_model.dart';
import '../services/tenant_service.dart';

class AddEditTenantScreen extends StatefulWidget {
  final String rentalId;
  final Tenant? tenant;

  const AddEditTenantScreen({
    Key? key,
    required this.rentalId,
    this.tenant,
  }) : super(key: key);

  @override
  State<AddEditTenantScreen> createState() => _AddEditTenantScreenState();
}

class _AddEditTenantScreenState extends State<AddEditTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  final TenantService _tenantService = TenantService();
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _unitController;
  late TextEditingController _rentController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _emergencyPhoneController;
  late TextEditingController _securityDepositController;
  late TextEditingController _notesController;
  
  DateTime _moveInDate = DateTime.now();
  String _status = 'active';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final tenant = widget.tenant;
    
    _nameController = TextEditingController(text: tenant?.name ?? '');
    _emailController = TextEditingController(text: tenant?.email ?? '');
    _phoneController = TextEditingController(text: tenant?.phone ?? '');
    _unitController = TextEditingController(text: tenant?.unitNumber ?? '');
    _rentController = TextEditingController(
      text: tenant?.rentAmount.toString() ?? '',
    );
    _emergencyContactController = TextEditingController(
      text: tenant?.emergencyContact ?? '',
    );
    _emergencyPhoneController = TextEditingController(
      text: tenant?.emergencyPhone ?? '',
    );
    _securityDepositController = TextEditingController(
      text: tenant?.securityDeposit?.toString() ?? '',
    );
    _notesController = TextEditingController(text: tenant?.notes ?? '');
    
    if (tenant != null) {
      _moveInDate = tenant.moveInDate;
      _status = tenant.status;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _unitController.dispose();
    _rentController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _securityDepositController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.tenant != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Tenant' : 'Add Tenant'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information Section
              _buildSectionHeader('Basic Information'),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
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
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Enter a valid email';
                  }
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Rental Information Section
              _buildSectionHeader('Rental Information'),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit Number *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Unit number is required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _rentController,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Rent *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Rent amount is required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Enter a valid amount';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              ListTile(
                title: const Text('Move In Date'),
                subtitle: Text(_moveInDate.toString().split(' ')[0]),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectMoveInDate,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(color: Colors.grey[400]!),
                ),
              ),
              
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info),
                ),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'moved_out', child: Text('Moved Out')),
                ],
                onChanged: (value) {
                  setState(() {
                    _status = value!;
                  });
                },
              ),
              
              const SizedBox(height: 24),
              
              // Emergency Contact Section
              _buildSectionHeader('Emergency Contact (Optional)'),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _emergencyContactController,
                decoration: const InputDecoration(
                  labelText: 'Emergency Contact Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.contact_emergency),
                ),
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _emergencyPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Emergency Contact Phone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_in_talk),
                ),
                keyboardType: TextInputType.phone,
              ),
              
              const SizedBox(height: 24),
              
              // Additional Information Section
              _buildSectionHeader('Additional Information'),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _securityDepositController,
                decoration: const InputDecoration(
                  labelText: 'Security Deposit',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.security),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              
              const SizedBox(height: 32),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTenant,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    isEditing ? 'Update Tenant' : 'Add Tenant',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      ),
    );
  }

  Future<void> _selectMoveInDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _moveInDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() {
        _moveInDate = date;
      });
    }
  }

  Future<void> _saveTenant() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final tenant = Tenant(
        id: widget.tenant?.id ?? '',
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        unitNumber: _unitController.text.trim(),
        rentAmount: double.parse(_rentController.text),
        moveInDate: _moveInDate,
        moveOutDate: widget.tenant?.moveOutDate,
        status: _status,
        emergencyContact: _emergencyContactController.text.trim().isEmpty 
            ? null 
            : _emergencyContactController.text.trim(),
        emergencyPhone: _emergencyPhoneController.text.trim().isEmpty 
            ? null 
            : _emergencyPhoneController.text.trim(),
        securityDeposit: _securityDepositController.text.trim().isEmpty 
            ? null 
            : double.parse(_securityDepositController.text),
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
        createdAt: widget.tenant?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.tenant != null) {
        // Update existing tenant
        await _tenantService.updateTenant(widget.rentalId, tenant);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tenant updated successfully')),
        );
      } else {
        // Add new tenant
        await _tenantService.addTenant(widget.rentalId, tenant);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tenant added successfully')),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}