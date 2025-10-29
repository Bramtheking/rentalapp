import 'package:cloud_firestore/cloud_firestore.dart';

class SMSMessage {
  final String id;
  final String message;
  final List<String> recipients;
  final String recipientType; // 'individual', 'group'
  final String status; // 'pending', 'sent', 'failed'
  final DateTime createdAt;
  final DateTime? sentAt;
  final String? errorMessage;
  final int smsCount;
  final double cost;
  final String? templateId;
  final bool isScheduled;
  final DateTime? scheduledAt;

  SMSMessage({
    required this.id,
    required this.message,
    required this.recipients,
    required this.recipientType,
    required this.status,
    required this.createdAt,
    this.sentAt,
    this.errorMessage,
    required this.smsCount,
    required this.cost,
    this.templateId,
    required this.isScheduled,
    this.scheduledAt,
  });

  factory SMSMessage.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SMSMessage(
      id: doc.id,
      message: data['message'] ?? '',
      recipients: List<String>.from(data['recipients'] ?? []),
      recipientType: data['recipientType'] ?? 'individual',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      sentAt: data['sentAt'] != null ? (data['sentAt'] as Timestamp).toDate() : null,
      errorMessage: data['errorMessage'],
      smsCount: data['smsCount'] ?? 1,
      cost: (data['cost'] ?? 0).toDouble(),
      templateId: data['templateId'],
      isScheduled: data['isScheduled'] ?? false,
      scheduledAt: data['scheduledAt'] != null ? (data['scheduledAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'message': message,
      'recipients': recipients,
      'recipientType': recipientType,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'errorMessage': errorMessage,
      'smsCount': smsCount,
      'cost': cost,
      'templateId': templateId,
      'isScheduled': isScheduled,
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
    };
  }
}

class SMSTemplate {
  final String id;
  final String title;
  final String message;
  final List<String> variables; // e.g., [TENANT_NAME], [AMOUNT], etc.
  final String category; // 'rent', 'maintenance', 'welcome', etc.
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  SMSTemplate({
    required this.id,
    required this.title,
    required this.message,
    required this.variables,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
  });

  factory SMSTemplate.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SMSTemplate(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      variables: List<String>.from(data['variables'] ?? []),
      category: data['category'] ?? 'general',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'variables': variables,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }
}

class SMSBalance {
  final String id;
  final int totalCredits;
  final int usedCredits;
  final int remainingCredits;
  final DateTime lastUpdated;
  final List<SMSTransaction> transactions;

  SMSBalance({
    required this.id,
    required this.totalCredits,
    required this.usedCredits,
    required this.remainingCredits,
    required this.lastUpdated,
    required this.transactions,
  });

  factory SMSBalance.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SMSBalance(
      id: doc.id,
      totalCredits: data['totalCredits'] ?? 0,
      usedCredits: data['usedCredits'] ?? 0,
      remainingCredits: data['remainingCredits'] ?? 0,
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      transactions: (data['transactions'] as List<dynamic>? ?? [])
          .map((t) => SMSTransaction.fromMap(t as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'totalCredits': totalCredits,
      'usedCredits': usedCredits,
      'remainingCredits': remainingCredits,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'transactions': transactions.map((t) => t.toMap()).toList(),
    };
  }
}

class SMSTransaction {
  final String type; // 'purchase', 'usage', 'refund'
  final int amount;
  final String description;
  final DateTime timestamp;
  final String? referenceId;

  SMSTransaction({
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
    this.referenceId,
  });

  factory SMSTransaction.fromMap(Map<String, dynamic> data) {
    return SMSTransaction(
      type: data['type'] ?? '',
      amount: data['amount'] ?? 0,
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      referenceId: data['referenceId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'amount': amount,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'referenceId': referenceId,
    };
  }
}