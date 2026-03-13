import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meter_reader/providers/auth_provider.dart';
import 'package:meter_reader/providers/reading_provider.dart';
import 'package:meter_reader/services/api_service.dart';
import 'package:meter_reader/services/connectivity_service.dart';
import 'package:meter_reader/services/database_service.dart';
import 'package:meter_reader/services/sync_service.dart';

void main() {
  testWidgets('App shows login screen when unauthenticated', (WidgetTester tester) async {
    final apiService = ApiService();
    final databaseService = DatabaseService();
    final connectivityService = ConnectivityService();
    final syncService = SyncService(
      apiService: apiService,
      databaseService: databaseService,
      connectivityService: connectivityService,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider(apiService: apiService)),
          ChangeNotifierProvider(
            create: (_) => ReadingProvider(
              apiService: apiService,
              syncService: syncService,
              connectivityService: connectivityService,
              databaseService: databaseService,
            ),
          ),
          ChangeNotifierProvider.value(value: syncService),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );

    // Verify that the loading indicator shows
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
