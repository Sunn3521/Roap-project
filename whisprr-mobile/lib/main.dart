import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_mobile.dart';
import 'theme_provider.dart';
import 'services/local_network_service.dart';
import 'services/device_pairing_service.dart';
import 'services/message_media_service.dart';
import 'services/connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final themeProvider = ThemeProvider();
  await themeProvider.init();
  
  final connectivityService = ConnectivityService();
  await connectivityService.initialize();
  
  final devicePairingService = DevicePairingService();
  await devicePairingService.initialize();
  
  final messagingService = MessageMediaService();
  await messagingService.initialize();
  
  final networkService = LocalNetworkService();
  // Only start network service if WiFi is available
  if (connectivityService.isWiFiConnected) {
    await networkService.initialize();
  }

  runApp(MyApp(
    themeProvider: themeProvider,
    connectivityService: connectivityService,
    devicePairingService: devicePairingService,
    messagingService: messagingService,
    networkService: networkService,
  ));
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final ConnectivityService connectivityService;
  final DevicePairingService devicePairingService;
  final MessageMediaService messagingService;
  final LocalNetworkService networkService;

  const MyApp({
    super.key,
    required this.themeProvider,
    required this.connectivityService,
    required this.devicePairingService,
    required this.messagingService,
    required this.networkService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: connectivityService),
        ChangeNotifierProvider.value(value: devicePairingService),
        ChangeNotifierProvider.value(value: messagingService),
        ChangeNotifierProvider.value(value: networkService),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MyAppMobile(themeProvider: theme);
        },
      ),
    );
  }
}
