import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/sms_service.dart';

class SMSScreen extends StatefulWidget {
  const SMSScreen({super.key});

  @override
  State<SMSScreen> createState() => _SMSScreenState();
}

class _SMSScreenState extends State<SMSScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final SMSService _smsService = SMSService();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  late TabController _tabController;
  Map<String, dynamic>? currentUser;
  String? selectedRentalId;
  bool isLoading = true;
  bool isSending = false;
  
  // SMS Balance and stats
  String smsBalance = 'Unknown';
  List<Map<String, dynamic>> smsLogs = [];
  
  // Recipients selection
  String selectedRecipientType = 'individual';
  List<String> selectedPhones = [];
  
  // SIM card selection (0 = SIM1, 1 = SIM2)
  int selectedSimSlot = 0;
  
  // Message templates
  List<Map<String, String>> messageTemplates = [
    {
      'title': 'Rent Reminder',
      'message': 'Dear [TENANT_NAME], this is a friendly reminder that your rent of KES [AMOUNT] is due on [DATE]. Please make payment to avoid late fees. Thank you.'
    },
    {
      'title': 'Payment Confirmation',
      'message': 'Dear [TENANT_NAME], we have received your rent payment of KES [AMOUNT] for [MONTH]. Thank you for your prompt payment.'
    },
    {
      'title': 'Maintenance Notice',
      'message': 'Dear [TENANT_NAME], we will be conducting maintenance in your unit [UNIT_NUMBER] on [DATE] from [TIME]. Please ensure access. Thank you.'
    },
    {
      'title': 'Welcome Message',
      'message': 'Welcome to [PROPERTY_NAME]! We are excited to have you as our tenant. For any inquiries, please contact us at [CONTACT]. Welcome home!'
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
    _loadSimPreference();
  }
  
  Future<void> _loadSimPreference() async {
    final simSlot = await _smsService.getPreferredSimSlot();
    setState(() {
      selectedSimSlot = simSlot;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
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
      
      // Load SMS balance and logs
      await _loadSMSData();
    }
  }

  Future<void> _loadSMSData() async {
    try {
      // Auto-sync SMS messages from device when screen loads
      if (selectedRentalId != null) {
        try {
          await _smsService.syncSMSMessages(selectedRentalId!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('SMS messages synced successfully'),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          print('SMS sync error (may not be on mobile): $e');
          // Don't show error to user as this is expected on non-mobile platforms
        }
      }
      
      // Get SMS balance
      Map<String, dynamic> balanceResult = await _smsService.getSMSBalance();
      
      // Get SMS logs
      List<Map<String, dynamic>> logs = await _smsService.getSMSLogs(limit: 20);
      
      setState(() {
        smsBalance = balanceResult['balance']?.toString() ?? 'Unknown';
        smsLogs = logs;
      });
    } catch (e) {
      print('Error loading SMS data: $e');
    }
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
        title: const Text('SMS Communications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync SMS from device',
            onPressed: () async {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Syncing SMS messages...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                await _smsService.syncSMSMessages(selectedRentalId!);
                await _loadSMSData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('SMS synced successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sync failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.phone_android, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text(
                  'FREE SMS',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Compose'),
            Tab(text: 'Templates'),
          ],
        ),
      ),
      body: Column(
        children: [
          // SMS Balance Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF667eea).withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.sms, color: Color(0xFF667eea), size: 24),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SMS Method',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const Text(
                      'Direct from Device (FREE)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'Current SMS credits available',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildComposeTab(),
                _buildTemplatesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compose SMS Header
          const Text(
            'Compose SMS',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Send SMS messages to tenants',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // SIM Card Selection (for dual SIM phones)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sim_card, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'SIM Card Selection',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<int>(
                        title: const Text('SIM 1'),
                        value: 0,
                        groupValue: selectedSimSlot,
                        onChanged: (value) async {
                          setState(() {
                            selectedSimSlot = value!;
                          });
                          await _smsService.setPreferredSimSlot(value!);
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<int>(
                        title: const Text('SIM 2'),
                        value: 1,
                        groupValue: selectedSimSlot,
                        onChanged: (value) async {
                          setState(() {
                            selectedSimSlot = value!;
                          });
                          await _smsService.setPreferredSimSlot(value!);
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                Text(
                  'SMS will be sent from SIM ${selectedSimSlot + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Recipients Section
          const Text(
            'Recipients',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Recipient Type Selection
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Individual'),
                  value: 'individual',
                  groupValue: selectedRecipientType,
                  onChanged: (value) {
                    setState(() {
                      selectedRecipientType = value!;
                      selectedPhones.clear();
                    });
                  },
                  dense: true,
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Group'),
                  value: 'group',
                  groupValue: selectedRecipientType,
                  onChanged: (value) {
                    setState(() {
                      selectedRecipientType = value!;
                      selectedPhones.clear();
                    });
                  },
                  dense: true,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Phone Number Input or Group Selection
          if (selectedRecipientType == 'individual') ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Enter phone number',
                      hintText: '+254712345678',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                    onFieldSubmitted: (_) => _addPhoneNumber(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _addPhoneNumber,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Quick tenant selection
            ElevatedButton.icon(
              onPressed: _showTenantSelector,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.blue.shade200),
              ),
              icon: const Icon(Icons.people),
              label: const Text('Select from Tenants'),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Group:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All Tenants'),
                        selected: selectedPhones.contains('all'),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedPhones.clear();
                              selectedPhones.add('all');
                            } else {
                              selectedPhones.remove('all');
                            }
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Active Tenants'),
                        selected: selectedPhones.contains('active'),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedPhones.clear();
                              selectedPhones.add('active');
                            } else {
                              selectedPhones.remove('active');
                            }
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Tenants with Arrears'),
                        selected: selectedPhones.contains('arrears'),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedPhones.clear();
                              selectedPhones.add('arrears');
                            } else {
                              selectedPhones.remove('arrears');
                            }
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Paid Late'),
                        selected: selectedPhones.contains('paid_late'),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedPhones.clear();
                              selectedPhones.add('paid_late');
                            } else {
                              selectedPhones.remove('paid_late');
                            }
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Overdue 7+ Days'),
                        selected: selectedPhones.contains('overdue_7'),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedPhones.clear();
                              selectedPhones.add('overdue_7');
                            } else {
                              selectedPhones.remove('overdue_7');
                            }
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Overdue 30+ Days'),
                        selected: selectedPhones.contains('overdue_30'),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedPhones.clear();
                              selectedPhones.add('overdue_30');
                            } else {
                              selectedPhones.remove('overdue_30');
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Selected Recipients Display
          if (selectedPhones.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF764ba2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF764ba2).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selected Recipients:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: selectedPhones.map((phone) {
                      return Chip(
                        label: Text(_getDisplayName(phone)),
                        onDeleted: () {
                          setState(() {
                            selectedPhones.remove(phone);
                          });
                        },
                        backgroundColor: const Color(0xFF764ba2).withOpacity(0.2),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Message Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Message',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _showTemplateSelector,
                    icon: const Icon(Icons.text_snippet),
                    label: const Text('Insert Template'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _showScheduleDialog,
                    icon: const Icon(Icons.schedule),
                    label: const Text('Schedule SMS'),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Message Input
          TextFormField(
            controller: _messageController,
            decoration: const InputDecoration(
              hintText: 'Type your message here...',
              border: OutlineInputBorder(),
            ),
            maxLines: 6,
            maxLength: 160,
            onChanged: (value) {
              setState(() {}); // Update character count
            },
          ),
          
          const SizedBox(height: 16),
          
          // Message Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_messageController.text.length} characters',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                'Estimated cost: ${_calculateSMSCost()} SMS credits',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Send Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: selectedPhones.isNotEmpty && _messageController.text.isNotEmpty && !isSending
                  ? _sendSMS
                  : null,
              icon: isSending 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(isSending ? 'Sending...' : 'Send SMS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return Column(
      children: [
        // Templates Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message Templates',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Pre-defined messages for quick sending',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddTemplateDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Template'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        // Templates List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: messageTemplates.length,
            itemBuilder: (context, index) {
              final template = messageTemplates[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    template['title']!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    template['message']!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _handleTemplateAction(value, template),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'use',
                        child: ListTile(
                          leading: Icon(Icons.send),
                          title: Text('Use Template'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Edit'),
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
                  onTap: () => _useTemplate(template),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _addPhoneNumber() {
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty && !selectedPhones.contains(phone)) {
      setState(() {
        selectedPhones.add(phone);
        _phoneController.clear();
      });
    }
  }

  String _getDisplayName(String phone) {
    switch (phone) {
      case 'all':
        return 'All Tenants';
      case 'active':
        return 'Active Tenants';
      case 'arrears':
        return 'Tenants with Arrears';
      case 'overdue_7':
        return 'Overdue 7+ Days';
      case 'overdue_30':
        return 'Overdue 30+ Days';
      default:
        return phone;
    }
  }

  int _calculateSMSCost() {
    final messageLength = _messageController.text.length;
    final smsCount = (messageLength / 160).ceil();
    return smsCount * selectedPhones.length;
  }

  void _sendSMS() async {
    if (selectedPhones.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select recipients and enter a message'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm SMS Send'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recipients: ${selectedPhones.length}'),
            const SizedBox(height: 8),
            const Text('Message Preview:'),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _messageController.text.length > 100 
                    ? '${_messageController.text.substring(0, 100)}...'
                    : _messageController.text,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text('Estimated cost: ${_calculateSMSCost()} SMS credits'),
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
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send SMS'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      isSending = true;
    });

    try {
      Map<String, dynamic> result;
      
      if (selectedRecipientType == 'individual') {
        // Send to individual numbers
        if (selectedPhones.length == 1) {
          result = await _smsService.sendSMS(
            phoneNumber: selectedPhones.first,
            message: _messageController.text,
            simSlot: selectedSimSlot,
          );
        } else {
          result = await _smsService.sendBulkSMS(
            phoneNumbers: selectedPhones,
            message: _messageController.text,
            simSlot: selectedSimSlot,
          );
        }
      } else {
        // Send to groups
        String groupType = selectedPhones.first;
        result = await _smsService.sendSMSToGroup(
          buildingId: selectedRentalId!,
          groupType: groupType,
          message: _messageController.text,
          simSlot: selectedSimSlot,
        );
      }

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear form
        setState(() {
          selectedPhones.clear();
          _messageController.clear();
          _phoneController.clear();
        });
        
        // Reload SMS data
        await _loadSMSData();
      } else {
        _showErrorDialog('SMS Failed', result['message']);
      }
    } catch (e) {
      _showErrorDialog('Connection Error', 'Unable to connect to SMS service. Please check your internet connection and try again.');
    } finally {
      setState(() {
        isSending = false;
      });
    }
  }

  void _showTenantSelector() async {
    try {
      // Get tenants from the building
      final tenants = await _smsService.getTenants(selectedRentalId!);
      
      if (tenants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tenants found in this building')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Tenants'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: tenants.length,
              itemBuilder: (context, index) {
                final tenant = tenants[index];
                final phone = tenant.phone;
                final name = tenant.name;
                final unit = tenant.unitNumber;
                final isSelected = selectedPhones.contains(phone);
                
                return CheckboxListTile(
                  title: Text(name),
                  subtitle: Text('Unit: $unit • Phone: $phone'),
                  value: isSelected,
                  onChanged: phone.isEmpty ? null : (bool? value) {
                    setState(() {
                      if (value == true) {
                        if (!selectedPhones.contains(phone)) {
                          selectedPhones.add(phone);
                        }
                      } else {
                        selectedPhones.remove(phone);
                      }
                    });
                    Navigator.pop(context);
                    _showTenantSelector(); // Refresh dialog
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading tenants: $e')),
      );
    }
  }

  void _showTemplateSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Template'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: messageTemplates.length,
            itemBuilder: (context, index) {
              final template = messageTemplates[index];
              return ListTile(
                title: Text(template['title']!),
                subtitle: Text(
                  template['message']!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  _messageController.text = template['message']!;
                  Navigator.pop(context);
                  setState(() {});
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showScheduleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule SMS'),
        content: const Text('SMS scheduling will be available in the next update. For now, you can send SMS immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRechargeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recharge SMS Credits'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Recharge your SMS credits via M-Pesa'),
            SizedBox(height: 16),
            Text('Available packages:'),
            SizedBox(height: 8),
            Text('• 100 SMS - KES 200'),
            Text('• 500 SMS - KES 900'),
            Text('• 1000 SMS - KES 1,700'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('M-Pesa integration coming soon!'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
            ),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }

  void _showAddTemplateDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Template Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
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
              if (titleController.text.isNotEmpty && messageController.text.isNotEmpty) {
                setState(() {
                  messageTemplates.add({
                    'title': titleController.text,
                    'message': messageController.text,
                  });
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Template added successfully!')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _handleTemplateAction(String action, Map<String, String> template) {
    switch (action) {
      case 'use':
        _useTemplate(template);
        break;
      case 'edit':
        _editTemplate(template);
        break;
      case 'delete':
        _deleteTemplate(template);
        break;
    }
  }

  void _useTemplate(Map<String, String> template) {
    _messageController.text = template['message']!;
    _tabController.animateTo(0); // Switch to compose tab
    setState(() {});
  }

  void _editTemplate(Map<String, String> template) {
    final titleController = TextEditingController(text: template['title']);
    final messageController = TextEditingController(text: template['message']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Template Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
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
              if (titleController.text.isNotEmpty && messageController.text.isNotEmpty) {
                setState(() {
                  final index = messageTemplates.indexOf(template);
                  messageTemplates[index] = {
                    'title': titleController.text,
                    'message': messageController.text,
                  };
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Template updated successfully!')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteTemplate(Map<String, String> template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                messageTemplates.remove(template);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Template deleted successfully!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Troubleshooting Tips:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('• Check your internet connection'),
                  const Text('• Verify phone numbers are correct'),
                  const Text('• Try again in a few minutes'),
                  const Text('• Contact support if problem persists'),
                ],
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
            onPressed: () {
              Navigator.pop(context);
              // Retry the SMS
              _sendSMS();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}