import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/media_service.dart';
import 'theme/app_theme.dart';
import 'pages/config_page.dart';
import 'pages/browser_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Carrega URL salva
  final prefs = await SharedPreferences.getInstance();
  final url = prefs.getString('server_url');
  if (url != null) MediaService.setBaseUrl(url);

  runApp(LnMidiaApp(urlSalva: url));
}

class LnMidiaApp extends StatelessWidget {
  final String? urlSalva;
  const LnMidiaApp({this.urlSalva, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LN Mídia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.tema,
      // Se já tem URL salva, vai direto para o browser
      home: urlSalva != null ? const BrowserPage() : const ConfigPage(),
    );
  }
}
