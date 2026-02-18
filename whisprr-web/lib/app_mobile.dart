import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'splash_screen.dart';
import 'theme_provider.dart';

class MyAppMobile extends StatelessWidget {
  final ThemeProvider themeProvider;

  const MyAppMobile({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, _) {
        return MaterialApp(
          title: 'Whisprr (Mobile)',
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          themeMode: theme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
