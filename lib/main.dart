import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/reading_provider.dart';
import 'services/env_config.dart';
import 'services/api_service.dart';
import 'services/connectivity_service.dart';
import 'services/database_service.dart';
import 'services/sync_service.dart';
import 'screens/login_screen.dart';
import 'screens/app_shell.dart';
import 'screens/capture_screen.dart';
import 'screens/pending_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const envFile = String.fromEnvironment(
    'ENV_FILE',
    defaultValue: '.env',
  );
  await EnvConfig.load(fileName: envFile);

  final apiService = ApiService();
  final databaseService = DatabaseService();
  final connectivityService = ConnectivityService();
  final syncService = SyncService(
    apiService: apiService,
    databaseService: databaseService,
    connectivityService: connectivityService,
  );

  final authProvider = AuthProvider(apiService: apiService);
  apiService.onAuthExpired = () {
    authProvider.handleAuthExpired();
  };

  runApp(MeterReaderApp(
    apiService: apiService,
    syncService: syncService,
    connectivityService: connectivityService,
    databaseService: databaseService,
    authProvider: authProvider,
  ));
}

class MeterReaderApp extends StatelessWidget {
  final ApiService apiService;
  final SyncService syncService;
  final ConnectivityService connectivityService;
  final DatabaseService databaseService;
  final AuthProvider authProvider;

  const MeterReaderApp({
    super.key,
    required this.apiService,
    required this.syncService,
    required this.connectivityService,
    required this.databaseService,
    required this.authProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        Provider.value(value: databaseService),
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
      child: MaterialApp(
        title: 'Fuel Op',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const AppShell(),
          '/capture': (context) => const CaptureScreen(),
          '/pending': (context) => const PendingScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.initial:
          case AuthStatus.loading:
            return Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                      child: const Icon(
                        Icons.local_gas_station_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'INITIALIZING SYSTEM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          case AuthStatus.authenticated:
            return const AppShell();
          case AuthStatus.unauthenticated:
            return const LoginScreen();
        }
      },
    );
  }
}
