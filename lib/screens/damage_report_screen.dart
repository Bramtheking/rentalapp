import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/unit_model.dart';
import '../services/unit_service.dart';

class DamageReportScreen extends StatefulWidget {
  final String rentalId;
  final DamageReport? damageReport;

  const DamageReportScreen({
    Key? key,
    required this.rentalId,
    this.damageReport,
  }) : super(key: key);

  @override
  State<DamageReportScreen> createState() => _DamageReportScreenState();
}

class _DamageReportScreenState extends State<DamageReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final UnitService _unitService = UnitService();
  
  late TextEditingController _damageIdController;
  late TextEditingController _descriptionController;
  late TextEditingController _reportedByController;
  late TextEditingController _repairNotesController;
  late TextEditingController _repairCostController;
  
  String? _selectedUnitNumber;
  String _selectedUnitName = '';
  String _selectedStatus = 'pending';
  String _selectedPriority = 'medium';
  DateTime _dateReported = DateTime.now();
  DateTime? _repairDate;
  List<Unit> _availableUnits = [];
  bool _isLoading = false;
  bool _isLoadingUnits = true;

  final List<String> _statusOptions = [
    'pending',
    'in_progress',
    'repaired',
  ];

  final List<String> _priorityOptions = [
    'low',
    'medium',
    'high',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadUnits();
  }

  void _initializeControllers() {
    final report = widget.damageReport;
    
    _damageIdController = TextEditingController(text: report?.damageId ?? '');
    _descriptionController = TextEditingController(text: report?.description ?? '');
    _reportedByController = TextEditingController(text: report?.reportedBy ?? '');
    _repairNotesController = TextEditingController(text: report?.repairNotes ?? '');
    _repairCostController = TextEditingController(
      text: report?.repairCost?.toString() ?? '',
    );
    
    if (report != null) {
      _selectedUnitNumber = report.unitNumber;
      _selectedUnitName = report.unitName;
      _selectedStatus = report.status;
      _selectedPriority = report.priority;
      _dateReported = report.dateReported;
      _repairDate = report.repairDate;
    }
  }

  Future<void> _loadUnits() async {
    try {
      final unitsStream = _unitService.getUnits(widget.rentalId);
      unitsStream.listen((units) {
        setState(() {
          _availableUnits = units;
          _isLoadingUnits = false;
        });
      });
    } catch (e) {
      setState(() {
        _isLoadingUnits = false;
      });
    }
  }

  @override
  void dispose() {
    _damageIdController.dispose();
    _descriptionController.dispose();
    _reportedByController.dispose();
    _repairNotesController.dispose();
    _repairCostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.damageReport != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Damage Report' : 'Report Damage'),
        backgroundColor: Colors.red[700],
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
              // Report Information Section
              _buildSectionHeader('Report Information'),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _damageIdController,
                      decoration: const InputDecoration(
                        labelText: 'Damage ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tag),
                        hintText: 'Auto-generated if empty',
                      ),
                      readOnly: isEditing,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _isLoadingUnits
                        ? const Center(child: CircularProgressIndicator())
                        : DropdownButtonFormField<String>(
                            value: _selectedUnitNumber,
                            decoration: const InputDecoration(
                              labelText: 'Unit *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.home),
                            ),
                            hint: const Text('Select Unit'),
                            items: _availableUnits.map((unit) {
                              return DropdownMenuItem(
                                value: unit.unitNumber,
                                child: Text('${unit.unitNumber} - ${unit.unitName}'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedUnitNumber = value;
                                final selectedUnit = _availableUnits.firstWhere(
                                  (unit) => unit.id == value,
                                );
                                _selectedUnitName = selectedUnit.unitName;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a unit';
                              }
                              return null;
                            },
                          ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Damage Description *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  hintText: 'Describe the damage in detail...',
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Damage description is required';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _reportedByController,
                      decoration: const InputDecoration(
                        labelText: 'Reported By *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Reporter name is required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ListTile(
                      title: const Text('Date Reported'),
                      subtitle: Text(_dateReported.toString().split(' ')[0]),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _selectDateReported,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedStatus,
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedPriority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.priority_high),
                      ),
                      items: _priorityOptions.map((priority) {
                        Color color = Colors.grey;
                        switch (priority) {
                          case 'low':
                            color = Colors.green;
                            break;
                          case 'medium':
                            color = Colors.orange;
                            break;
                          case 'high':
                            color = Colors.red;
                            break;
                        }
                        return DropdownMenuItem(
                          value: priority,
                          child: Row(
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
                              Text(priority.toUpperCase()),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPriority = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Repair Information Section (only show if status is not pending)
              if (_selectedStatus != 'pending') ...[
                _buildSectionHeader('Repair Information'),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _repairNotesController,
                  decoration: const InputDecoration(
                    labelText: 'Repair Notes',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                    hintText: 'Notes about the repair work...',
                  ),
                  maxLines: 3,
                ),
                
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _repairCostController,
                        decoration: const InputDecoration(
                          labelText: 'Repair Cost (KES)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ListTile(
                        title: const Text('Repair Date'),
                        subtitle: Text(_repairDate?.toString().split(' ')[0] ?? 'Not set'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _selectRepairDate,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
              ],
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveDamageReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    isEditing ? 'Update Report' : 'Submit Report',
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
        color: Colors.red,
      ),
    );
  }

  Future<void> _selectDateReported() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateReported,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() {
        _dateReported = date;
      });
    }
  }

  Future<void> _selectRepairDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _repairDate ?? DateTime.now(),
      firstDate: _dateReported,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() {
        _repairDate = date;
      });
    }
  }

  Future<void> _saveDamageReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String damageId = _damageIdController.text.trim();
      
      // Generate damage ID if not provided
      if (damageId.isEmpty) {
        damageId = await _unitService.generateDamageId(widget.rentalId);
      }

      final report = DamageReport(
        id: widget.damageReport?.id ?? '',
        damageId: damageId,
        description: _descriptionController.text.trim(),
        unitNumber: _selectedUnitNumber!,
        unitName: _selectedUnitName,
        reportedBy: _reportedByController.text.trim(),
        dateReported: _dateReported,
        status: _selectedStatus,
        priority: _selectedPriority,
        repairNotes: _repairNotesController.text.trim().isEmpty 
            ? null 
            : _repairNotesController.text.trim(),
        repairDate: _repairDate,
        repairCost: _repairCostController.text.trim().isEmpty 
            ? null 
            : double.parse(_repairCostController.text),
        images: widget.damageReport?.images ?? [], // TODO: Implement image upload
        createdAt: widget.damageReport?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.damageReport != null) {
        // Update existing report
        await _unitService.updateDamageReport(widget.rentalId, report);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Damage report updated successfully')),
        );
      } else {
        // Add new report
        await _unitService.addDamageReport(widget.rentalId, report);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Damage report submitted successfully')),
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