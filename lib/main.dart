import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trimvo/core/router/app_router.dart';
import 'package:trimvo/core/theme/app_theme.dart';
import 'package:trimvo/providers/auth_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: TrimvoApp()));
}

class TrimvoApp extends ConsumerStatefulWidget {
  const TrimvoApp({super.key});

  @override
  ConsumerState<TrimvoApp> createState() => _TrimvoAppState();
}

class _TrimvoAppState extends ConsumerState<TrimvoApp> {
  @override
  void initState() {
    super.initState();
    ref.read(authProvider.notifier).loadFromStorage().then((_) {
      if (ref.read(authProvider).isLoggedIn) {
        ref.read(authProvider.notifier).refreshBalance();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Trimvo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
