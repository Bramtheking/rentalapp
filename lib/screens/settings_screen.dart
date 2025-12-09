import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/sms_service.dart';

class SettingsScreen extends StatefulWidget {
  final String? selectedBuildingId;

  const SettingsScreen({Key? key, this.selectedBuildingId}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SMSService _smsService = SMSService();
  bool _isLoading = true;
  bool _autoSyncEnabled = false;
  int _syncIntervalMinutes = 2;
  String? _smsSender;
  DateTime? _lastSyncDate;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (widget.selectedBuildingId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load sync settings
      final autoSync = await _smsService.isAutoSyncEnabled(widget.selectedBuildingId!);
      final sender = await _smsService.getBuildingSMSSender(widget.selectedBuildingId!);
      final lastSync = await _smsService.getSyncStartDate(widget.selectedBuildingId!);
      
      // Load sync interval from building settings
      final buildingDoc = await FirebaseFirestore.instance
          .collection('rentals')
          .doc(widget.selectedBuildingId!)
          .get();
      
      final interval = buildingDoc.data()?['syncIntervalMinutes'] ?? 2;

      setState(() {
        _autoSyncEnabled = autoSync;
        _smsSender = sender;
        _lastSyncDate = lastSync;
        _syncIntervalMinutes = interval;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAutoSyncSetting(bool enabled) async {
    if (widget.selectedBuildingId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('rentals')
          .doc(widget.selectedBuildingId!)
          .update({'autoSyncEnabled': enabled});

      setState(() => _autoSyncEnabled = enabled);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled ? 'Auto-sync enabled' : 'Auto-sync disabled'),
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

  Future<void> _saveSyncInterval(int minutes) async {
    if (widget.selectedBuildingId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('rentals')
          .doc(widget.selectedBuildingId!)
          .update({'syncIntervalMinutes': minutes});

      setState(() => _syncIntervalMinutes = minutes);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync interval updated'),
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

  Future<void> _resetSyncDate() async {
    if (widget.selectedBuildingId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Sync Date'),
        content: const Text(
          'This will reset the sync start date to now. All future SMS syncs will only process messages from this point forward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _smsService.setSyncStartDate(widget.selectedBuildingId!, DateTime.now());
      
      setState(() => _lastSyncDate = DateTime.now());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync date reset successfully'),
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

  @override
  Widget build(BuildContext context) {
    if (widget.selectedBuildingId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'No Building Selected',
                style: TextStyle(fontSize: 20, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a building to view settings',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // SMS Sync Settings Section
          _buildSectionHeader('SMS Sync Settings'),
          const SizedBox(height: 12),
          
          // Auto-sync toggle
          _buildSettingCard(
            icon: Icons.sync,
            title: 'Auto-Sync SMS',
            subtitle: _smsService.isWeb 
                ? 'Not available on web platform'
                : 'Automatically sync SMS messages in background',
            trailing: Switch(
              value: _autoSyncEnabled,
              onChanged: _smsService.isWeb ? null : _saveAutoSyncSetting,
              activeColor: const Color(0xFF667eea),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Sync interval
          _buildSettingCard(
            icon: Icons.timer,
            title: 'Sync Interval',
            subtitle: 'How often to check for new SMS messages',
            trailing: DropdownButton<int>(
              value: _syncIntervalMinutes,
              onChanged: _autoSyncEnabled && !_smsService.isWeb
                  ? (value) {
                      if (value != null) _saveSyncInterval(value);
                    }
                  : null,
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 minute')),
                DropdownMenuItem(value: 2, child: Text('2 minutes')),
                DropdownMenuItem(value: 5, child: Text('5 minutes')),
                DropdownMenuItem(value: 10, child: Text('10 minutes')),
                DropdownMenuItem(value: 15, child: Text('15 minutes')),
                DropdownMenuItem(value: 30, child: Text('30 minutes')),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // SMS Sender info
          _buildSettingCard(
            icon: Icons.phone_android,
            title: 'SMS Sender',
            subtitle: _smsSender ?? 'Not configured',
            trailing: const Icon(Icons.info_outline, color: Colors.grey),
          ),
          
          const SizedBox(height: 12),
          
          // Last sync date
          _buildSettingCard(
            icon: Icons.history,
            title: 'Last Sync Date',
            subtitle: _lastSyncDate != null
                ? '${_lastSyncDate!.day}/${_lastSyncDate!.month}/${_lastSyncDate!.year} ${_lastSyncDate!.hour}:${_lastSyncDate!.minute.toString().padLeft(2, '0')}'
                : 'Never synced',
            trailing: TextButton(
              onPressed: _resetSyncDate,
              child: const Text('Reset'),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Auto-sync only works on mobile devices. Web version does not support SMS reading.',
                    style: TextStyle(
                      color: Colors.blue[900],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF667eea),
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF667eea)),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}
