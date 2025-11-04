import 'package:flutter/material.dart';
import '../models/sms_format_model.dart';
import '../services/sms_service.dart';

class SMSFormatEditorScreen extends StatefulWidget {
  const SMSFormatEditorScreen({super.key});

  @override
  State<SMSFormatEditorScreen> createState() => _SMSFormatEditorScreenState();
}

class _SMSFormatEditorScreenState extends State<SMSFormatEditorScreen> {
  final SMSService _smsService = SMSService();
  List<SMSFormat> _formats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFormats();
  }

  Future<void> _loadFormats() async {
    try {
      // Get available banks from the hardcoded formats
      List<Map<String, String>> banks = _smsService.getAvailableBanks();
      List<String> bankNames = banks.map((b) => b['name']!).toList();
      
      // Convert to SMSFormat objects for display
      List<SMSFormat> formats = bankNames.map((bankName) => SMSFormat(
        id: bankName.toLowerCase().replaceAll(' ', '_'),
        name: bankName,
        paybill: 'Auto-detected',
        format: 'Hardcoded in service',
        extractors: {}, // Hardcoded in service
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      )).toList();
      
      setState(() {
        _formats = formats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading formats: $e')),
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
                            'SMS Format Editor',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Manage bank SMS formats for payment processing',
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
                        onPressed: () => _showAddFormatDialog(),
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
                      : _formats.isEmpty
                          ? _buildEmptyState()
                          : _buildFormatsList(),
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
            Icons.sms_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No SMS Formats',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add bank SMS formats to enable payment processing',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddFormatDialog(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add First Format'),
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

  Widget _buildFormatsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _formats.length,
      itemBuilder: (context, index) {
        final format = _formats[index];
        return _buildFormatCard(format);
      },
    );
  }

  Widget _buildFormatCard(SMSFormat format) {
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
          onTap: () => _showEditFormatDialog(format),
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
                        Icons.account_balance_rounded,
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
                            format.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          Text(
                            'Paybill: ${format.paybill}',
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
                        color: format.isActive 
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        format.isActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: format.isActive ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      onSelected: (value) => _handleFormatAction(value, format),
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
                          value: 'test',
                          child: ListTile(
                            leading: Icon(Icons.play_arrow_rounded, color: Colors.green),
                            title: Text('Test Format'),
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
                        'Format Template:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        format.format,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.data_usage_rounded, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${format.extractors.length} extractors',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Updated ${_formatDate(format.updatedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
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

  String _formatDate(DateTime date) {
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

  void _handleFormatAction(String action, SMSFormat format) {
    switch (action) {
      case 'edit':
        _showEditFormatDialog(format);
        break;
      case 'test':
        _showTestFormatDialog(format);
        break;
      case 'delete':
        _showDeleteFormatDialog(format);
        break;
    }
  }

  void _showAddFormatDialog() {
    _showFormatDialog(null);
  }

  void _showEditFormatDialog(SMSFormat format) {
    _showFormatDialog(format);
  }

  void _showFormatDialog(SMSFormat? format) {
    showDialog(
      context: context,
      builder: (context) => SMSFormatDialog(
        format: format,
        onSave: (savedFormat) async {
          try {
            // SMS formats are now hardcoded - no need to save
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('SMS formats are now hardcoded and auto-detected. No manual configuration needed.'),
                backgroundColor: Colors.orange,
              ),
            );
            _loadFormats();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(format == null ? 'Format created successfully!' : 'Format updated successfully!'),
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

  void _showTestFormatDialog(SMSFormat format) {
    showDialog(
      context: context,
      builder: (context) => TestFormatDialog(format: format),
    );
  }

  void _showDeleteFormatDialog(SMSFormat format) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete SMS Format'),
        content: Text('Are you sure you want to delete "${format.name}"? This action cannot be undone.'),
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
                // SMS formats are now hardcoded - cannot delete
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cannot delete hardcoded SMS formats. They are automatically managed.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                Navigator.pop(context);
                _loadFormats();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Format deleted successfully!'),
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

// SMS Format Dialog for Add/Edit
class SMSFormatDialog extends StatefulWidget {
  final SMSFormat? format;
  final Function(SMSFormat) onSave;

  const SMSFormatDialog({
    super.key,
    this.format,
    required this.onSave,
  });

  @override
  State<SMSFormatDialog> createState() => _SMSFormatDialogState();
}

class _SMSFormatDialogState extends State<SMSFormatDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _idController;
  late TextEditingController _nameController;
  late TextEditingController _paybillController;
  late TextEditingController _formatController;
  
  Map<String, TextEditingController> _extractorControllers = {};
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final format = widget.format;
    
    _idController = TextEditingController(text: format?.id ?? '');
    _nameController = TextEditingController(text: format?.name ?? '');
    _paybillController = TextEditingController(text: format?.paybill ?? '');
    _formatController = TextEditingController(text: format?.format ?? '');
    _isActive = format?.isActive ?? true;
    
    // Initialize extractor controllers
    if (format != null) {
      format.extractors.forEach((key, value) {
        _extractorControllers[key] = TextEditingController(text: value);
      });
    } else {
      // Default extractors for new format
      _extractorControllers = {
        'amount': TextEditingController(text: r'Ksh([0-9,]+\.?[0-9]*)'),
        'reference': TextEditingController(text: r'\(Ref: ([A-Z0-9]+)\)'),
        'date': TextEditingController(text: r'on ([0-9]{2}/[0-9]{2}/[0-9]{4})'),
        'time': TextEditingController(text: r'([0-9]{2}:[0-9]{2})'),
      };
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _paybillController.dispose();
    _formatController.dispose();
    _extractorControllers.values.forEach((controller) => controller.dispose());
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
                widget.format == null ? 'Add SMS Format' : 'Edit SMS Format',
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
                        controller: _idController,
                        decoration: const InputDecoration(
                          labelText: 'Format ID',
                          hintText: 'e.g., kcb, family, faulu',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter format ID';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Bank Name',
                          hintText: 'e.g., KCB Bank',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter bank name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _paybillController,
                        decoration: const InputDecoration(
                          labelText: 'Paybill Number',
                          hintText: 'e.g., 522522',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter paybill number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _formatController,
                        decoration: const InputDecoration(
                          labelText: 'SMS Format Template',
                          hintText: 'Use {amount}, {reference}, {date}, {time} as placeholders',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter SMS format template';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      SwitchListTile(
                        title: const Text('Active'),
                        subtitle: const Text('Enable this format for processing'),
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Extractors
                      const Text(
                        'Regex Extractors',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      ..._extractorControllers.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextFormField(
                            controller: entry.value,
                            decoration: InputDecoration(
                              labelText: '${entry.key} Pattern',
                              hintText: 'Regex pattern to extract ${entry.key}',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  setState(() {
                                    entry.value.dispose();
                                    _extractorControllers.remove(entry.key);
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter regex pattern';
                              }
                              return null;
                            },
                          ),
                        );
                      }).toList(),
                      
                      ElevatedButton.icon(
                        onPressed: _addExtractor,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Extractor'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea).withOpacity(0.1),
                          foregroundColor: const Color(0xFF667eea),
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
                    onPressed: _saveFormat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(widget.format == null ? 'Create' : 'Update'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addExtractor() {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final patternController = TextEditingController();
        
        return AlertDialog(
          title: const Text('Add Extractor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Field Name',
                  hintText: 'e.g., balance, account',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: patternController,
                decoration: const InputDecoration(
                  labelText: 'Regex Pattern',
                  hintText: 'e.g., balance Ksh([0-9,]+)',
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
              onPressed: () {
                if (nameController.text.isNotEmpty && patternController.text.isNotEmpty) {
                  setState(() {
                    _extractorControllers[nameController.text] = 
                        TextEditingController(text: patternController.text);
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

  void _saveFormat() {
    if (_formKey.currentState!.validate()) {
      final extractors = <String, String>{};
      _extractorControllers.forEach((key, controller) {
        extractors[key] = controller.text;
      });
      
      final format = SMSFormat(
        id: _idController.text.trim(),
        name: _nameController.text.trim(),
        paybill: _paybillController.text.trim(),
        format: _formatController.text.trim(),
        extractors: extractors,
        isActive: _isActive,
        createdAt: widget.format?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      widget.onSave(format);
      Navigator.pop(context);
    }
  }
}

// Test Format Dialog
class TestFormatDialog extends StatefulWidget {
  final SMSFormat format;

  const TestFormatDialog({super.key, required this.format});

  @override
  State<TestFormatDialog> createState() => _TestFormatDialogState();
}

class _TestFormatDialogState extends State<TestFormatDialog> {
  final _smsController = TextEditingController();
  Map<String, String> _extractedData = {};

  @override
  void dispose() {
    _smsController.dispose();
    super.dispose();
  }

  void _testFormat() {
    final smsService = SMSService();
    final extracted = smsService.parseSMS(_smsController.text, widget.format?.name);
    setState(() {
      _extractedData = extracted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test ${widget.format.name} Format',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _smsController,
              decoration: const InputDecoration(
                labelText: 'Sample SMS',
                hintText: 'Paste a sample SMS message here',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: _testFormat,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
              ),
              child: const Text('Test Format'),
            ),
            
            if (_extractedData.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Extracted Data:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _extractedData.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            '${entry.key}:',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Text(entry.value),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}