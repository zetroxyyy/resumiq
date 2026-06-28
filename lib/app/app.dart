import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:khalti_flutter/khalti_flutter.dart';
import '../core/constants/app_constants.dart';
import 'router.dart';
import 'theme.dart';

class ResumindApp extends ConsumerWidget {
  const ResumindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return KhaltiScope(
      publicKey: AppConstants.khaltiPublicKey,
      enabledDebugging: true,
      navigatorKey: rootNavigatorKey,
      builder: (context, navigatorKey) {
        return MaterialApp.router(
          title: 'Resumind',
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          localizationsDelegates: const [
            KhaltiLocalizations.delegate,
          ],
        );
      },
    );
  }
}
