import 'dart:convert';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

// ─────────────────────────────────────────────
// CONFIGURAÇÃO — altere conforme o cliente
// ─────────────────────────────────────────────
const mediaRoot = r'F:\SERIES'; // pasta raiz dos filmes/séries
const porta = 8080;
// ─────────────────────────────────────────────

final extensoesVideo = {'.mp4', '.mkv', '.avi', '.mov', '.m4v', '.wmv'};

void main() async {
  final router = Router();

  // GET /api/media/list?path=Séries/Breaking+Bad
  router.get('/api/media/list', _listar);

  // GET /api/media/stream?path=Filmes/Oppenheimer.mkv
  router.get('/api/media/stream', _stream);

  final handler = Pipeline()
      .addMiddleware(_cors())
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, porta);
  print('═══════════════════════════════════════');
  print('  LN Mídia Server rodando');
  print('  http://${server.address.host}:${server.port}');
  print('  Pasta raiz: $mediaRoot');
  print('═══════════════════════════════════════');
}

// ── Lista pastas e arquivos ──────────────────
Response _listar(Request req) {
  final pathParam = req.url.queryParameters['path'] ?? '';
  final fullPath = pathParam.isEmpty
      ? mediaRoot
      : '$mediaRoot${Platform.pathSeparator}${pathParam.replaceAll('/', Platform.pathSeparator)}';

  final dir = Directory(fullPath);
  if (!dir.existsSync()) {
    return Response.notFound(jsonEncode({'erro': 'Pasta não encontrada'}),
        headers: {'Content-Type': 'application/json'});
  }

  final itens = <Map<String, dynamic>>[];

  for (final entry in dir.listSync()) {
    final nome = entry.path.split(Platform.pathSeparator).last;
    // ignora arquivos ocultos
    if (nome.startsWith('.')) continue;

    final isDir = entry is Directory;
    if (!isDir && !_isVideo(nome)) continue;

    final rel = pathParam.isEmpty ? nome : '$pathParam/$nome';
    itens.add({
      'name': nome,
      'path': rel,
      'type': isDir ? 'folder' : 'video',
      'size': isDir ? 0 : File(entry.path).lengthSync(),
    });
  }

  // Pastas primeiro, depois arquivos, ambos em ordem alfabética
  itens.sort((a, b) {
    if (a['type'] != b['type']) return a['type'] == 'folder' ? -1 : 1;
    return (a['name'] as String)
        .toLowerCase()
        .compareTo((b['name'] as String).toLowerCase());
  });

  return Response.ok(
    jsonEncode(itens),
    headers: {'Content-Type': 'application/json'},
  );
}

// ── Stream de vídeo com suporte a Range ──────
Future<Response> _stream(Request req) async {
  final pathParam = req.url.queryParameters['path'] ?? '';
  final fullPath =
      '$mediaRoot${Platform.pathSeparator}${pathParam.replaceAll('/', Platform.pathSeparator)}';

  final file = File(fullPath);
  if (!file.existsSync()) {
    return Response.notFound('Arquivo não encontrado');
  }

  final fileSize = file.lengthSync();
  final mimeType = lookupMimeType(file.path) ?? 'video/mp4';
  final rangeHeader = req.headers['range'];

  if (rangeHeader != null) {
    final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
    if (match != null) {
      final start = int.parse(match.group(1)!);
      final rawEnd = match.group(2);
      final end = (rawEnd != null && rawEnd.isNotEmpty)
          ? int.parse(rawEnd)
          : (start + 2 * 1024 * 1024).clamp(0, fileSize - 1) as int;

      final length = end - start + 1;

      return Response(
        206,
        body: file.openRead(start, end + 1),
        headers: {
          'Content-Type': mimeType,
          'Content-Range': 'bytes $start-$end/$fileSize',
          'Content-Length': '$length',
          'Accept-Ranges': 'bytes',
        },
      );
    }
  }

  return Response.ok(
    file.openRead(),
    headers: {
      'Content-Type': mimeType,
      'Content-Length': '$fileSize',
      'Accept-Ranges': 'bytes',
    },
  );
}

// ── Helpers ──────────────────────────────────
bool _isVideo(String nome) {
  final ext = nome.contains('.') ? '.${nome.split('.').last.toLowerCase()}' : '';
  return extensoesVideo.contains(ext);
}

Middleware _cors() {
  return (handler) => (req) async {
        final res = await handler(req);
        return res.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, OPTIONS',
        });
      };
}
