import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressoService {
  static const _prefixo = 'progresso_';
  static const _listaKey = 'lista_progresso';
  static const _maxItens = 20;

  // Salva posição em segundos
  static Future<void> salvar(String path, int segundos, int duracao) async {
    if (segundos < 5) return; // ignora posições muito no início
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'path': path,
      'segundos': segundos,
      'duracao': duracao,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await prefs.setString('$_prefixo$path', jsonEncode(data));
    await _atualizarLista(prefs, path);
  }

  // Recupera posição salva
  static Future<int> carregar(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefixo$path');
    if (raw == null) return 0;
    final data = jsonDecode(raw);
    final segundos = data['segundos'] as int;
    final duracao = data['duracao'] as int;
    // Se está nos últimos 5%, considera assistido — começa do início
    if (duracao > 0 && segundos / duracao > 0.95) return 0;
    return segundos;
  }

  // Remove progresso (quando terminou)
  static Future<void> remover(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefixo$path');
    final lista = await listarRecentes(prefs);
    lista.removeWhere((e) => e['path'] == path);
    await prefs.setString(_listaKey, jsonEncode(lista));
  }

  // Lista os recentes para tela "Continuar Assistindo"
  static Future<List<Map<String, dynamic>>> listarRecentes(
      [SharedPreferences? prefsParam]) async {
    final prefs = prefsParam ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(_listaKey);
    if (raw == null) return [];
    final List lista = jsonDecode(raw);
    // Recarrega dados atuais de cada item
    final resultado = <Map<String, dynamic>>[];
    for (final item in lista) {
      final path = item['path'] as String;
      final dadosRaw = prefs.getString('$_prefixo$path');
      if (dadosRaw != null) {
        resultado.add(Map<String, dynamic>.from(jsonDecode(dadosRaw)));
      }
    }
    resultado.sort((a, b) =>
        (b['timestamp'] as int).compareTo(a['timestamp'] as int));
    return resultado;
  }

  static Future<void> _atualizarLista(
      SharedPreferences prefs, String path) async {
    final raw = prefs.getString(_listaKey);
    List lista = raw != null ? jsonDecode(raw) : [];
    lista.removeWhere((e) => e['path'] == path);
    lista.insert(0, {'path': path});
    if (lista.length > _maxItens) lista = lista.sublist(0, _maxItens);
    await prefs.setString(_listaKey, jsonEncode(lista));
  }
}
