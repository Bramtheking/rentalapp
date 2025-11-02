import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sms_format_model.dart';
import '../services/sms_service.dart';

class PaymentStructureScreen extends StatefulWidget {
  final String buildingId;
  final String buildingName;

  const PaymentStructureScreen({
    super.key,
    required this.buildingId,
    required this.buildingName,
  });

  @override
  State<PaymentStructureScreen> createState() => _PaymentStructureScreenState();
}

class _PaymentStructureScreenState extends State<PaymentStructureScreen> {
  final SMSService _smsService = SMSService();
  Map<String, PaymentStructure> _paymentStructures = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentStructures();
  }

  Future<void> _loadPaymentStructures() async {
    try {
      final structures = await _smsService.getPaymentStructures(widget.buildingId);
      setState(() {
        _paymentStructures = structures;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading payment structures: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
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
                        Icons.payment_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Structure',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Configure rent breakdown for ${widget.buildingName}',
                            style: const TextStyle(
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
                        onPressed: () => _showAddPaymentStructureDialog(),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                          ),
                        )
                      : _paymentStructures.isEmpty
                          ? _buildEmptyState()
                          : _buildPaymentStructuresList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.payment_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Payment Structures',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add payment structures for your units',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddPaymentStructureDialog(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Payment Structure'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStructuresList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _paymentStructures.length,
      itemBuilder: (context, index) {
        final entry = _paymentStructures.entries.elementAt(index);
        final unitRef = entry.key;
        final structure = entry.value;
        return _buildPaymentStructureCard(unitRef, structure);
      },
    );
  }

  Widget _buildPaymentStructureCard(String unitRef, PaymentStructure structure) {
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
          onTap: () => _showEditPaymentStructureDialog(unitRef, structure),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.home_work_rounded,
                        color: const Color(0xFF667eea),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unit $unitRef',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          Text(
                            'Total: KES ${structure.totalRent.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Due: ${structure.dueDate}${_getOrdinalSuffix(structure.dueDate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      onSelected: (value) => _handlePaymentStructureAction(value, unitRef, structure),
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
                const SizedBox(height: 16),
                
                // Payment Breakdown
                Container(
                  padding: const EdgeInsets.all(16),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...structure.breakdown.entries.map((entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
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
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Penalties
                if (structure.penalties.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Penalties:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...structure.penalties.entries.map((entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key.replaceAll('PerDay', ' per day').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red[600],
                                ),
                              ),
                              Text(
                                'KES ${entry.value.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                        )),
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

  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) {
      return 'th';
    }
    switch (number % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  void _handlePaymentStructureAction(String action, String unitRef, PaymentStructure structure) {
    switch (action) {
      case 'edit':
        _showEditPaymentStructureDialog(unitRef, structure);
        break;
      case 'delete':
        _showDeletePaymentStructureDialog(unitRef);
        break;
    }
  }

  void _showAddPaymentStructureDialog() {
    _showPaymentStructureDialog(null, null);
  }

  void _showEditPaymentStructureDialog(String unitRef, PaymentStructure structure) {
    _showPaymentStructureDialog(unitRef, structure);
  }

  void _showPaymentStructureDialog(String? unitRef, PaymentStructure? structure) {
    showDialog(
      context: context,
      builder: (context) => PaymentStructureDialog(
        unitRef: unitRef,
        structure: structure,
        onSave: (savedUnitRef, savedStructure) async {
          try {
            await _smsService.setPaymentStructure(widget.buildingId, savedUnitRef, savedStructure);
            _loadPaymentStructures();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(structure == null ? 'Payment structure created successfully!' : 'Payment structure updated successfully!'),
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
        },
      ),
    );
  }

  void _showDeletePaymentStructureDialog(String unitRef) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Payment Structure'),
        content: Text('Are you sure you want to delete the payment structure for unit "$unitRef"? This action cannot be undone.'),
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
              try {
                // Delete from Firestore
                await FirebaseFirestore.instance
                    .collection('rentals')
                    .doc(widget.buildingId)
                    .update({
                  'paymentStructure.$unitRef': FieldValue.delete(),
                });
                
                Navigator.pop(context);
                _loadPaymentStructures();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment structure deleted successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Payment Structure Dialog for Add/Edit
class PaymentStructureDialog extends StatefulWidget {
  final String? unitRef;
  final PaymentStructure? structure;
  final Function(String, PaymentStructure) onSave;

  const PaymentStructureDialog({
    super.key,
    this.unitRef,
    this.structure,
    required this.onSave,
  });

  @override
  State<PaymentStructureDialog> createState() => _PaymentStructureDialogState();
}

class _PaymentStructureDialogState extends State<PaymentStructureDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _unitRefController;
  late TextEditingController _dueDateController;
  
  Map<String, TextEditingController> _breakdownControllers = {};
  Map<String, TextEditingController> _penaltyControllers = {};

  @override
  void initState() {
    super.initState();
    final structure = widget.structure;
    
    _unitRefController = TextEditingController(text: widget.unitRef ?? '');
    _dueDateController = TextEditingController(text: (structure?.dueDate ?? 5).toString());
    
    // Initialize breakdown controllers
    if (structure != null) {
      structure.breakdown.forEach((key, value) {
        _breakdownControllers[key] = TextEditingController(text: value.toString());
      });
      structure.penalties.forEach((key, value) {
        _penaltyControllers[key] = TextEditingController(text: value.toString());
      });
    } else {
      // Default breakdown for new structure
      _breakdownControllers = {
        'rent': TextEditingController(text: '5500'),
        'water': TextEditingController(text: '120'),
        'bin': TextEditingController(text: '100'),
      };
      _penaltyControllers = {
        'lateRentPerDay': TextEditingController(text: '250'),
        'partialPaymentPerDay': TextEditingController(text: '50'),
      };
    }
  }

  @override
  void dispose() {
    _unitRefController.dispose();
    _dueDateController.dispose();
    _breakdownControllers.values.forEach((controller) => controller.dispose());
    _penaltyControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.structure == null ? 'Add Payment Structure' : 'Edit Payment Structure',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 24),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Info
                      TextFormField(
                        controller: _unitRefController,
                        decoration: const InputDecoration(
                          labelText: 'Unit Reference',
                          hintText: 'e.g., A11, B05',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter unit reference';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _dueDateController,
                        decoration: const InputDecoration(
                          labelText: 'Due Date (Day of Month)',
                          hintText: 'e.g., 5 for 5th of each month',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter due date';
                          }
                          final day = int.tryParse(value);
                          if (day == null || day < 1 || day > 31) {
                            return 'Please enter a valid day (1-31)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Payment Breakdown
                      const Text(
                        'Payment Breakdown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      ..._breakdownControllers.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextFormField(
                            controller: entry.value,
                            decoration: InputDecoration(
                              labelText: '${entry.key.toUpperCase()} Amount',
                              hintText: 'Enter amount in KES',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  setState(() {
                                    entry.value.dispose();
                                    _breakdownControllers.remove(entry.key);
                                  });
                                },
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter amount';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid amount';
                              }
                              return null;
                            },
                          ),
                        );
                      }).toList(),
                      
                      ElevatedButton.icon(
                        onPressed: _addBreakdownItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Breakdown Item'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea).withOpacity(0.1),
                          foregroundColor: const Color(0xFF667eea),
                          elevation: 0,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Penalties
                      const Text(
                        'Penalties',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      ..._penaltyControllers.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextFormField(
                            controller: entry.value,
                            decoration: InputDecoration(
                              labelText: '${entry.key.replaceAll('PerDay', ' Per Day').toUpperCase()}',
                              hintText: 'Enter penalty amount in KES',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  setState(() {
                                    entry.value.dispose();
                                    _penaltyControllers.remove(entry.key);
                                  });
                                },
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter penalty amount';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid amount';
                              }
                              return null;
                            },
                          ),
                        );
                      }).toList(),
                      
                      ElevatedButton.icon(
                        onPressed: _addPenaltyItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Penalty'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          foregroundColor: Colors.red,
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _savePaymentStructure,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(widget.structure == null ? 'Create' : 'Update'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addBreakdownItem() {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final amountController = TextEditingController();
        
        return AlertDialog(
          title: const Text('Add Breakdown Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'e.g., electricity, security',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (KES)',
                  hintText: 'e.g., 50',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && amountController.text.isNotEmpty) {
                  setState(() {
                    _breakdownControllers[nameController.text.toLowerCase()] = 
                        TextEditingController(text: amountController.text);
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addPenaltyItem() {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final amountController = TextEditingController();
        
        return AlertDialog(
          title: const Text('Add Penalty'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Penalty Name',
                  hintText: 'e.g., latePaymentPerDay',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Penalty Amount (KES)',
                  hintText: 'e.g., 100',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && amountController.text.isNotEmpty) {
                  setState(() {
                    _penaltyControllers[nameController.text] = 
                        TextEditingController(text: amountController.text);
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _savePaymentStructure() {
    if (_formKey.currentState!.validate()) {
      final breakdown = <String, double>{};
      _breakdownControllers.forEach((key, controller) {
        breakdown[key] = double.parse(controller.text);
      });
      
      final penalties = <String, double>{};
      _penaltyControllers.forEach((key, controller) {
        penalties[key] = double.parse(controller.text);
      });
      
      final totalRent = breakdown.values.fold(0.0, (sum, amount) => sum + amount);
      
      final structure = PaymentStructure(
        unitRef: _unitRefController.text.trim(),
        totalRent: totalRent,
        breakdown: breakdown,
        dueDate: int.parse(_dueDateController.text),
        penalties: penalties,
      );
      
      widget.onSave(_unitRefController.text.trim(), structure);
      Navigator.pop(context);
    }
  }
}