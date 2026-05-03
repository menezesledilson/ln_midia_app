import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/media_service.dart';
import '../theme/app_theme.dart';
import 'browser_page.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final _ctrl = TextEditingController();
  bool _testando = false;
  String? _mensagem;
  bool _sucesso = false;

  @override
  void initState() {
    super.initState();
    _carregarUrl();
  }

  Future<void> _carregarUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('server_url') ?? 'http://192.168.1.100:8080';
    _ctrl.text = url;
    MediaService.setBaseUrl(url);
  }

  Future<void> _salvarETestar() async {
    setState(() {
      _testando = true;
      _mensagem = null;
    });

    final url = _ctrl.text.trim();
    MediaService.setBaseUrl(url);

    final ok = await MediaService().testarConexao();

    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_url', url);
    }

    setState(() {
      _testando = false;
      _sucesso = ok;
      _mensagem = ok ? 'Conectado com sucesso!' : 'Não foi possível conectar. Verifique o IP e se o servidor está rodando.';
    });

    if (ok && mounted) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BrowserPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'LN Mídia',
                style: TextStyle(
                  color: AppTheme.corTexto,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Configure o endereço do servidor',
                style: TextStyle(color: AppTheme.corTextoMudo, fontSize: 15),
              ),
              const SizedBox(height: 48),
              const Text(
                'IP do servidor',
                style: TextStyle(
                  color: AppTheme.corTextoMudo,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.url,
                style: const TextStyle(color: AppTheme.corTexto),
                decoration: InputDecoration(
                  hintText: 'http://192.168.1.100:8080',
                  hintStyle: const TextStyle(color: AppTheme.corTextoMudo),
                  filled: true,
                  fillColor: AppTheme.corSuperficie,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.corPrimaria),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ex: http://192.168.1.100:8080',
                style: TextStyle(color: AppTheme.corTextoMudo, fontSize: 12),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _testando ? null : _salvarETestar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.corPrimaria,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _testando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Conectar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              if (_mensagem != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _sucesso
                        ? const Color(0xFF0F2A1A)
                        : const Color(0xFF2A0F0F),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _sucesso ? Icons.check_circle : Icons.error,
                        color: _sucesso ? Colors.greenAccent : Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _mensagem!,
                          style: TextStyle(
                            color: _sucesso
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
