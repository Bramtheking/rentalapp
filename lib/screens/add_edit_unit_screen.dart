import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/unit_model.dart';
import '../services/unit_service.dart';

class AddEditUnitScreen extends StatefulWidget {
  final String rentalId;
  final Unit? unit;

  const AddEditUnitScreen({
    super.key,
    required this.rentalId,
    this.unit,
  });

  @override
  State<AddEditUnitScreen> createState() => _AddEditUnitScreenState();
}

class _AddEditUnitScreenState extends State<AddEditUnitScreen> {
  final _formKey = GlobalKey<FormState>();
  final UnitService _unitService = UnitService();
  
  late TextEditingController _unitIdController;
  late TextEditingController _unitNameController;
  late TextEditingController _rentController;
  late TextEditingController _bedroomsController;
  late TextEditingController _bathroomsController;
  late TextEditingController _areaController;
  late TextEditingController _descriptionController;
  
  String _selectedType = '1 Bedroom';
  String _selectedStatus = 'vacant';
  List<String> _selectedAmenities = [];
  bool _isLoading = false;

  final List<String> _unitTypes = [
    '1 Bedroom',
    '2 Bedroom',
    '3 Bedroom',
    'Studio',
    'Bedsitter',
    'Single Room',
    'Shop',
    'Office',
  ];

  final List<String> _statusOptions = [
    'vacant',
    'occupied',
    'under_maintenance',
  ];

  final List<String> _availableAmenities = [
    'WiFi',
    'Parking',
    'Security',
    'Water',
    'Electricity',
    'Generator',
    'CCTV',
    'Gym',
    'Swimming Pool',
    'Garden',
    'Balcony',
    'Air Conditioning',
    'Heating',
    'Elevator',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final unit = widget.unit;
    
    _unitIdController = TextEditingController(text: unit?.unitId ?? '');
    _unitNameController = TextEditingController(text: unit?.unitName ?? '');
    _rentController = TextEditingController(
      text: unit?.rent.toString() ?? '',
    );
    _bedroomsController = TextEditingController(
      text: unit?.bedrooms.toString() ?? '1',
    );
    _bathroomsController = TextEditingController(
      text: unit?.bathrooms.toString() ?? '1',
    );
    _areaController = TextEditingController(
      text: unit?.area?.toString() ?? '',
    );
    _descriptionController = TextEditingController(text: unit?.description ?? '');
    
    if (unit != null) {
      _selectedType = unit.type;
      _selectedStatus = unit.status;
      _selectedAmenities = List.from(unit.amenities);
    }
  }

  @override
  void dispose() {
    _unitIdController.dispose();
    _unitNameController.dispose();
    _rentController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _areaController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.unit != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Unit' : 'Add Unit'),
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
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _unitIdController,
                      decoration: const InputDecoration(
                        labelText: 'Unit ID *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tag),
                        hintText: 'e.g., U001, A-101',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Unit ID is required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _unitNameController,
                      decoration: const InputDecoration(
                        labelText: 'Unit Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home),
                        hintText: 'e.g., Apartment A-101',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Unit name is required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Unit Type *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: _unitTypes.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.info),
                      ),
                      items: _statusOptions.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status.replaceAll('_', ' ').toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _rentController,
                decoration: const InputDecoration(
                  labelText: 'Monthly Rent (KES) *',
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
              
              const SizedBox(height: 24),
              
              // Unit Details Section
              _buildSectionHeader('Unit Details'),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bedroomsController,
                      decoration: const InputDecoration(
                        labelText: 'Bedrooms',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.bed),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (int.tryParse(value) == null) {
                            return 'Enter a valid number';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _bathroomsController,
                      decoration: const InputDecoration(
                        labelText: 'Bathrooms',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.bathroom),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (int.tryParse(value) == null) {
                            return 'Enter a valid number';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _areaController,
                      decoration: const InputDecoration(
                        labelText: 'Area (sq ft)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.square_foot),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              
              const SizedBox(height: 24),
              
              // Amenities Section
              _buildSectionHeader('Amenities'),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select available amenities:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableAmenities.map((amenity) {
                        final isSelected = _selectedAmenities.contains(amenity);
                        return FilterChip(
                          label: Text(amenity),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedAmenities.add(amenity);
                              } else {
                                _selectedAmenities.remove(amenity);
                              }
                            });
                          },
                          selectedColor: Colors.blue.withOpacity(0.3),
                          checkmarkColor: Colors.blue,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveUnit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    isEditing ? 'Update Unit' : 'Add Unit',
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

  Future<void> _saveUnit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final unit = Unit(
        id: widget.unit?.id ?? '',
        unitId: _unitIdController.text.trim(),
        unitName: _unitNameController.text.trim(),
        type: _selectedType,
        status: _selectedStatus,
        rent: double.parse(_rentController.text),
        tenantId: widget.unit?.tenantId,
        tenantName: widget.unit?.tenantName,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        bedrooms: int.tryParse(_bedroomsController.text) ?? 1,
        bathrooms: int.tryParse(_bathroomsController.text) ?? 1,
        area: _areaController.text.trim().isEmpty 
            ? null 
            : double.parse(_areaController.text),
        amenities: _selectedAmenities,
        createdAt: widget.unit?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.unit != null) {
        // Update existing unit
        await _unitService.updateUnit(widget.rentalId, unit);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unit updated successfully')),
        );
      } else {
        // Add new unit
        await _unitService.addUnit(widget.rentalId, unit);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unit added successfully')),
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