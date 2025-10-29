import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class SMSScreen extends StatefulWidget {
  const SMSScreen({Key? key}) : super(key: key);

  @override
  State<SMSScreen> createState() => _SMSScreenState();
}

class _SMSScreenState extends State<SMSScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  late TabController _tabController;
  Map<String, dynamic>? currentUser;
  String? selectedRentalId;
  bool isLoading = true;
  
  // SMS Balance and stats
  int smsBalance = 250;
  int totalSmsCredits = 500;
  
  // Recipients selection
  String selectedRecipientType = 'individual';
  List<String> selectedPhones = [];
  
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
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [
          ElevatedButton.icon(
            onPressed: () => _showRechargeDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Recharge via M-Pesa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange[700],
            ),
          ),
          const SizedBox(width: 16),
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
            color: Colors.orange[50],
            child: Row(
              children: [
                Icon(Icons.sms, color: Colors.orange[700], size: 24),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SMS Balance',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '$smsBalance messages remaining',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
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
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Enter phone number',
                hintText: '+254712345678',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone),
                suffixIcon: ElevatedButton(
                  onPressed: _addPhoneNumber,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ),
              keyboardType: TextInputType.phone,
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
                        selected: selectedPhones.contains('all_tenants'),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedPhones.clear();
                              selectedPhones.add('all_tenants');
                            } else {
                              selectedPhones.remove('all_tenants');
                            }
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Active Tenants'),
                        selected: selectedPhones.contains('active_tenants'),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedPhones.clear();
                              selectedPhones.add('active_tenants');
                            } else {
                              selectedPhones.remove('active_tenants');
                            }
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Tenants with Arrears'),
                        selected: selectedPhones.contains('arrears_tenants'),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedPhones.clear();
                              selectedPhones.add('arrears_tenants');
                            } else {
                              selectedPhones.remove('arrears_tenants');
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
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
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
                        backgroundColor: Colors.blue[100],
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
              onPressed: selectedPhones.isNotEmpty && _messageController.text.isNotEmpty
                  ? _sendSMS
                  : null,
              icon: const Icon(Icons.send),
              label: const Text('Send SMS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
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
                  backgroundColor: Colors.orange[700],
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
      case 'all_tenants':
        return 'All Tenants';
      case 'active_tenants':
        return 'Active Tenants';
      case 'arrears_tenants':
        return 'Tenants with Arrears';
      default:
        return phone;
    }
  }

  int _calculateSMSCost() {
    final messageLength = _messageController.text.length;
    final smsCount = (messageLength / 160).ceil();
    return smsCount * selectedPhones.length;
  }

  void _sendSMS() {
    // TODO: Implement SMS sending logic
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send SMS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recipients: ${selectedPhones.length}'),
            Text('Message: ${_messageController.text.substring(0, _messageController.text.length > 50 ? 50 : _messageController.text.length)}...'),
            Text('Cost: ${_calculateSMSCost()} SMS credits'),
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
                const SnackBar(content: Text('SMS sent successfully!')),
              );
              // Clear form
              setState(() {
                selectedPhones.clear();
                _messageController.clear();
                _phoneController.clear();
              });
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
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
        content: const Text('SMS scheduling feature coming soon!'),
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
                const SnackBar(content: Text('Recharge feature coming soon!')),
              );
            },
            child: const Text('Recharge'),
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
              final index = messageTemplates.indexOf(template);
              if (index != -1) {
                setState(() {
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                messageTemplates.remove(template);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Template deleted successfully!')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}