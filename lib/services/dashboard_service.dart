import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get comprehensive dashboard data
  Future<Map<String, dynamic>> getDashboardData(String rentalId) async {
    try {
      // Get all collections data in parallel
      final futures = await Future.wait([
        _getUnitsData(rentalId),
        _getTenantsData(rentalId),
        _getPaymentsData(rentalId),
        _getExpensesData(rentalId),
        _getRentalInfo(rentalId),
      ]);

      final unitsData = futures[0];
      final tenantsData = futures[1];
      final paymentsData = futures[2];
      final expensesData = futures[3];
      final rentalInfo = futures[4];

      // Calculate financial metrics
      final totalIncome = paymentsData['totalIncome'] ?? 0.0;
      final totalExpenses = expensesData['totalExpenses'] ?? 0.0;
      final netProfit = totalIncome - totalExpenses;
      final occupancyRate = unitsData['occupancyRate'] ?? 0.0;

      return {
        'rental': rentalInfo,
        'units': unitsData,
        'tenants': tenantsData,
        'payments': paymentsData,
        'expenses': expensesData,
        'financial': {
          'totalIncome': totalIncome,
          'totalExpenses': totalExpenses,
          'netProfit': netProfit,
          'occupancyRate': occupancyRate,
        },
        'lastUpdated': DateTime.now(),
      };
    } catch (e) {
      print('Error getting dashboard data: $e');
      return {};
    }
  }

  // Public method to get units data independently
  Future<Map<String, dynamic>> getUnitsData(String rentalId) async {
    return await _getUnitsData(rentalId);
  }

  // Public method to get tenants data independently
  Future<Map<String, dynamic>> getTenantsData(String rentalId) async {
    return await _getTenantsData(rentalId);
  }

  // Public method to get payments data independently
  Future<Map<String, dynamic>> getPaymentsData(String rentalId) async {
    return await _getPaymentsData(rentalId);
  }

  // Public method to get expenses data independently
  Future<Map<String, dynamic>> getExpensesData(String rentalId) async {
    return await _getExpensesData(rentalId);
  }

  // Get units statistics
  Future<Map<String, dynamic>> _getUnitsData(String rentalId) async {
    final snapshot = await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('units')
        .get();

    int totalUnits = snapshot.docs.length;
    int occupiedUnits = 0;
    int vacantUnits = 0;
    int maintenanceUnits = 0;
    double totalRent = 0;
    double occupiedRent = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final status = data['status'] ?? 'vacant';
      final rent = (data['rent'] ?? 0).toDouble();
      
      totalRent += rent;
      
      switch (status) {
        case 'occupied':
          occupiedUnits++;
          occupiedRent += rent;
          break;
        case 'vacant':
          vacantUnits++;
          break;
        case 'under_maintenance':
          maintenanceUnits++;
          break;
      }
    }

    double occupancyRate = totalUnits > 0 ? (occupiedUnits / totalUnits * 100) : 0;

    return {
      'totalUnits': totalUnits,
      'occupiedUnits': occupiedUnits,
      'vacantUnits': vacantUnits,
      'maintenanceUnits': maintenanceUnits,
      'occupancyRate': occupancyRate,
      'totalRent': totalRent,
      'occupiedRent': occupiedRent,
      'potentialRent': totalRent - occupiedRent,
    };
  }

  // Get tenants statistics
  Future<Map<String, dynamic>> _getTenantsData(String rentalId) async {
    final snapshot = await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('tenants')
        .get();

    int totalTenants = snapshot.docs.length;
    int activeTenants = 0;
    int movedOutTenants = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final status = data['status'] ?? 'active';
      
      switch (status) {
        case 'active':
          activeTenants++;
          break;
        case 'moved_out':
          movedOutTenants++;
          break;
      }
    }

    return {
      'totalTenants': totalTenants,
      'activeTenants': activeTenants,
      'movedOutTenants': movedOutTenants,
    };
  }

  // Get payments data for current month and trends
  Future<Map<String, dynamic>> _getPaymentsData(String rentalId) async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    
    // Get both current and last month payments in parallel
    final futures = await Future.wait([
      _firestore
          .collection('rentals')
          .doc(rentalId)
          .collection('payments')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(currentMonth))
          .limit(100) // Limit to improve performance
          .get(),
      _firestore
          .collection('rentals')
          .doc(rentalId)
          .collection('payments')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(lastMonth))
          .where('createdAt', isLessThan: Timestamp.fromDate(currentMonth))
          .limit(100) // Limit to improve performance
          .get(),
    ]);
    
    final currentMonthSnapshot = futures[0];
    final lastMonthSnapshot = futures[1];

    double currentMonthTotal = 0;
    double lastMonthTotal = 0;
    List<Map<String, dynamic>> dailyPayments = [];
    Map<String, double> paymentMethods = {};

    // Process current month payments
    for (var doc in currentMonthSnapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0).toDouble();
      final method = data['method'] ?? 'Unknown';
      final date = (data['createdAt'] as Timestamp).toDate();
      
      currentMonthTotal += amount;
      paymentMethods[method] = (paymentMethods[method] ?? 0) + amount;
      
      // Group by day for chart
      final dayKey = '${date.day}/${date.month}';
      dailyPayments.add({
        'date': dayKey,
        'amount': amount,
        'day': date.day,
      });
    }

    // Process last month payments
    for (var doc in lastMonthSnapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0).toDouble();
      lastMonthTotal += amount;
    }

    // Calculate growth
    double growthRate = 0;
    if (lastMonthTotal > 0) {
      growthRate = ((currentMonthTotal - lastMonthTotal) / lastMonthTotal) * 100;
    }

    // Group daily payments for chart
    Map<int, double> dailyTotals = {};
    for (var payment in dailyPayments) {
      int day = payment['day'];
      dailyTotals[day] = (dailyTotals[day] ?? 0) + payment['amount'];
    }

    return {
      'totalIncome': currentMonthTotal,
      'lastMonthIncome': lastMonthTotal,
      'growthRate': growthRate,
      'paymentMethods': paymentMethods,
      'dailyPayments': dailyTotals,
      'paymentsCount': currentMonthSnapshot.docs.length,
    };
  }

  // Get expenses data
  Future<Map<String, dynamic>> _getExpensesData(String rentalId) async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    
    final snapshot = await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(currentMonth))
        .get();

    double totalExpenses = 0;
    Map<String, double> expensesByCategory = {};
    int expensesCount = snapshot.docs.length;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0).toDouble();
      final category = data['category'] ?? 'Other';
      
      totalExpenses += amount;
      expensesByCategory[category] = (expensesByCategory[category] ?? 0) + amount;
    }

    return {
      'totalExpenses': totalExpenses,
      'expensesByCategory': expensesByCategory,
      'expensesCount': expensesCount,
    };
  }

  // Get rental information
  Future<Map<String, dynamic>> _getRentalInfo(String rentalId) async {
    final doc = await _firestore
        .collection('rentals')
        .doc(rentalId)
        .get();

    if (doc.exists) {
      return doc.data() ?? {};
    }
    return {};
  }

  // Get monthly trends for charts (last 6 months) - optimized
  Future<List<Map<String, dynamic>>> getMonthlyTrends(String rentalId) async {
    final now = DateTime.now();
    List<Map<String, dynamic>> trends = [];

    // Create all the futures first, then execute them in parallel
    List<Future<QuerySnapshot>> paymentFutures = [];
    List<Future<QuerySnapshot>> expenseFutures = [];
    List<DateTime> months = [];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(now.year, now.month - i + 1, 1);
      months.add(month);
      
      paymentFutures.add(
        _firestore
            .collection('rentals')
            .doc(rentalId)
            .collection('payments')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(month))
            .where('createdAt', isLessThan: Timestamp.fromDate(nextMonth))
            .limit(50) // Limit for performance
            .get()
      );

      expenseFutures.add(
        _firestore
            .collection('rentals')
            .doc(rentalId)
            .collection('expenses')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(month))
            .where('date', isLessThan: Timestamp.fromDate(nextMonth))
            .limit(50) // Limit for performance
            .get()
      );
    }

    // Execute all queries in parallel
    final paymentResults = await Future.wait(paymentFutures);
    final expenseResults = await Future.wait(expenseFutures);

    // Process results
    for (int i = 0; i < months.length; i++) {
      double monthlyIncome = 0;
      double monthlyExpenses = 0;

      for (var doc in paymentResults[i].docs) {
        final data = doc.data() as Map<String, dynamic>?;
        monthlyIncome += (data?['amount'] ?? 0).toDouble();
      }

      for (var doc in expenseResults[i].docs) {
        final data = doc.data() as Map<String, dynamic>?;
        monthlyExpenses += (data?['amount'] ?? 0).toDouble();
      }

      trends.add({
        'month': months[i],
        'monthName': _getMonthName(months[i].month),
        'income': monthlyIncome,
        'expenses': monthlyExpenses,
        'profit': monthlyIncome - monthlyExpenses,
      });
    }

    return trends;
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}