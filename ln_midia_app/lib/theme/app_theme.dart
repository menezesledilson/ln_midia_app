import 'package:flutter/material.dart';

class AppTheme {
  static const corPrimaria = Color(0xFF5566FF);
  static const corFundo = Color(0xFF0D0D1A);
  static const corSuperficie = Color(0xFF1A1A2E);
  static const corTexto = Color(0xFFE8E8FF);
  static const corTextoMudo = Color(0xFF55557A);
  static const corDivisor = Color(0xFF1E1E3A);

  static ThemeData get tema => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: corFundo,
        colorScheme: const ColorScheme.dark(
          primary: corPrimaria,
          surface: corSuperficie,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: corFundo,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: corTexto,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: corPrimaria),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: corPrimaria,
        ),
        dividerColor: corDivisor,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: corTexto),
          bodySmall: TextStyle(color: corTextoMudo),
        ),
      );
}
