import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';

class MediaService {
  static String _baseUrl = 'http://192.168.1.42:8080';

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Future<List<MediaItem>> listar(String path) async {
    final uri = Uri.parse(
        '$_baseUrl/api/media/list?path=${Uri.encodeComponent(path)}');
    final res = await http.get(uri).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) throw Exception('Erro ${res.statusCode}');

    final List data = jsonDecode(res.body);
    return data.map((e) => MediaItem.fromJson(e)).toList();
  }

  String streamUrl(String path) =>
      '$_baseUrl/api/media/stream?path=${Uri.encodeComponent(path)}';

  Future<bool> testarConexao() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/media/list?path=');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
