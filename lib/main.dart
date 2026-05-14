import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'theme/theme.dart';
import 'navigation/app_router.dart';
import 'services/notification_service.dart';
import 'services/iot_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseDatabase.instance.databaseURL =
      'https://pfe-smartschool-default-rtdb.europe-west1.firebasedatabase.app';
  await NotificationService().initialize();
  runApp(const ProviderScope(child: SmartSchoolApp()));
}

class SmartSchoolApp extends ConsumerStatefulWidget {
  const SmartSchoolApp({super.key});

  @override
  ConsumerState<SmartSchoolApp> createState() => _SmartSchoolAppState();
}

class _SmartSchoolAppState extends ConsumerState<SmartSchoolApp> {
  @override
  void initState() {
    super.initState();
    RfidScanListener.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Faccna',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
