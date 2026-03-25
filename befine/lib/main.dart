import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Try loading from --dart-define (Recommended for Web/Production)
    String url = const String.fromEnvironment('SUPABASE_URL');
    String anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

    // 2. Fallback to .env file if environment variables are empty
    if (url.isEmpty || anonKey.isEmpty) {
      try {
        await dotenv.load(fileName: ".env");
        url = dotenv.env['SUPABASE_URL'] ?? '';
        anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
      } catch (e) {
        debugPrint('Dotenv load failed: $e');
      }
    }

    if (url.isNotEmpty && anonKey.isNotEmpty) {
      await Supabase.initialize(url: url, anonKey: anonKey);
    } else {
      debugPrint('Warning: Supabase configuration is missing. The app may not function correctly.');
    }
  } catch (e) {
    debugPrint('Initialization Error: $e');
  }

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Befine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      routerConfig: AppRouter.router,
      builder: (context, child) {
        final isDark = themeMode == ThemeMode.dark || 
                      (themeMode == ThemeMode.system && 
                       WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.backgroundDark : null,
              gradient: isDark 
                  ? null 
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFBFBFF), // Very soft tinted white
                        Color(0xFFF3EDFA), // Soft purple wave
                        Color(0xFFEDF2FA), // Soft blue wave
                        Color(0xFFFBFBFF),
                      ],
                      stops: [0.0, 0.35, 0.65, 1.0],
                    ),
            ),
            child: child!,
          ),
        );
      },
    );
  }
}

