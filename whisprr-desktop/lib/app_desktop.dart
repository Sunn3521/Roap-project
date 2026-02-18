import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'theme_provider.dart';

class MyAppDesktop extends StatelessWidget {
  final ThemeProvider themeProvider;

  const MyAppDesktop({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, _) {
        print('🔧 MyAppDesktop build');
        return MaterialApp(
          title: 'Whisprr (Desktop)',
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          themeMode: theme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const HomeScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
