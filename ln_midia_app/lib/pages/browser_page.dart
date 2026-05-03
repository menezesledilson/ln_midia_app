import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/media_service.dart';
import '../services/progresso_service.dart';
import '../theme/app_theme.dart';
import 'player_page.dart';
import 'config_page.dart';

enum Ordenacao { nome, tamanho, tipo }

class BrowserPage extends StatefulWidget {
  final String path;
  final String title;

  const BrowserPage({
    this.path = '',
    this.title = 'LN Mídia',
    super.key,
  });

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  final _service = MediaService();
  late Future<List<MediaItem>> _future;
  Future<List<Map<String, dynamic>>>? _futureContinuar;

  final _buscaCtrl = TextEditingController();
  String _busca = '';
  Ordenacao _ordenacao = Ordenacao.nome;
  bool _buscaAtiva = false;

  @override
  void initState() {
    super.initState();
    _carregar();
    if (widget.path.isEmpty) {
      _futureContinuar = ProgressoService.listarRecentes();
    }
  }

  void _carregar() {
    _future = _service.listar(widget.path);
  }

  bool _isVideo(String nome) {
    final ext = nome.toLowerCase();
    return ext.endsWith('.mkv') ||
        ext.endsWith('.mp4') ||
        ext.endsWith('.avi') ||
        ext.endsWith('.mov') ||
        ext.endsWith('.m4v');
  }

  List<MediaItem> _filtrarOrdenar(List<MediaItem> itens) {
    var lista = itens.where((i) {
      if (_busca.isEmpty && !i.isFolder && !_isVideo(i.name)) return false;
      if (_busca.isEmpty) return true;
      return i.name.toLowerCase().contains(_busca.toLowerCase());
    }).toList();

    switch (_ordenacao) {
      case Ordenacao.nome:
        lista.sort((a, b) {
          if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case Ordenacao.tamanho:
        lista.sort((a, b) {
          if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
          return b.size.compareTo(a.size);
        });
        break;
      case Ordenacao.tipo:
        lista.sort((a, b) {
          if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
          return a.extensao.compareTo(b.extensao);
        });
        break;
    }

    return lista;
  }

  void _abrirVideo(MediaItem item, List<MediaItem> todosItens) {
    final videos =
        todosItens.where((i) => !i.isFolder && _isVideo(i.name)).toList();
    final indice = videos.indexWhere((v) => v.path == item.path);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          title: item.name,
          url: _service.streamUrl(item.path),
          path: item.path,
          playlist: videos,
          indiceAtual: indice >= 0 ? indice : 0,
        ),
      ),
    );
  }

  Future<void> _abrirVideoContinuar(String path) async {
    final pasta = path.substring(0, path.lastIndexOf('/'));
    final nome = path.split('/').last;
    final nav = Navigator.of(context);
    try {
      final itens = await _service.listar(pasta);
      final videos =
          itens.where((i) => !i.isFolder && _isVideo(i.name)).toList();
      final indice = videos.indexWhere((v) => v.path == path);
      if (!mounted) return;
      nav.push(MaterialPageRoute(
        builder: (_) => PlayerPage(
          title: nome,
          url: _service.streamUrl(path),
          path: path,
          playlist: videos,
          indiceAtual: indice >= 0 ? indice : 0,
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      nav.push(MaterialPageRoute(
        builder: (_) => PlayerPage(
          title: nome,
          url: _service.streamUrl(path),
          path: path,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRaiz = widget.path.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: _buscaAtiva
            ? TextField(
                controller: _buscaCtrl,
                autofocus: true,
                style: const TextStyle(color: AppTheme.corTexto),
                decoration: const InputDecoration(
                  hintText: 'Buscar...',
                  hintStyle: TextStyle(color: AppTheme.corTextoMudo),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _busca = v),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title),
                  if (isRaiz)
                    Text(MediaService.baseUrl,
                        style: const TextStyle(
                            color: AppTheme.corTextoMudo,
                            fontSize: 11,
                            fontWeight: FontWeight.w400)),
                ],
              ),
        leading: _buscaAtiva
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _buscaAtiva = false;
                  _busca = '';
                  _buscaCtrl.clear();
                }),
              )
            : (isRaiz ? null : const BackButton()),
        actions: [
          if (!_buscaAtiva) ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _buscaAtiva = true),
            ),
            PopupMenuButton<Ordenacao>(
              icon: const Icon(Icons.sort),
              color: const Color(0xFF1A1A2E),
              onSelected: (v) => setState(() => _ordenacao = v),
              itemBuilder: (_) => [
                _menuItem(Ordenacao.nome, 'Nome', Icons.sort_by_alpha),
                _menuItem(Ordenacao.tamanho, 'Tamanho', Icons.data_usage),
                _menuItem(Ordenacao.tipo, 'Tipo', Icons.category),
              ],
            ),
            if (isRaiz)
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ConfigPage()),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() {
                _carregar();
                if (isRaiz) {
                  _futureContinuar = ProgressoService.listarRecentes();
                }
              }),
            ),
          ],
        ],
      ),
      body: FutureBuilder<List<MediaItem>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: AppTheme.corPrimaria));
          }

          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off,
                        color: AppTheme.corTextoMudo, size: 48),
                    const SizedBox(height: 16),
                    const Text('Não foi possível conectar ao servidor.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.corTexto)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => setState(_carregar),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.corPrimaria),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final todosItens = snap.data!;
          final itens = _filtrarOrdenar(todosItens);

          return CustomScrollView(
            slivers: [
              if (isRaiz && _futureContinuar != null && _busca.isEmpty)
                SliverToBoxAdapter(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _futureContinuar,
                    builder: (ctx, snapC) {
                      final recentes = snapC.data ?? [];
                      if (recentes.isEmpty) return const SizedBox.shrink();
                      return _SecaoContinuar(
                        recentes: recentes,
                        service: _service,
                        onTap: _abrirVideoContinuar,
                        onRemover: (path) async {
                          await ProgressoService.remover(path);
                          setState(() {
                            _futureContinuar =
                                ProgressoService.listarRecentes();
                          });
                        },
                      );
                    },
                  ),
                ),

              if (itens.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text('Nenhum resultado',
                        style: TextStyle(color: AppTheme.corTextoMudo)),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final item = itens[i];
                      return Column(
                        children: [
                          item.isFolder
                              ? _FolderTile(item: item)
                              : _VideoTile(
                                  item: item,
                                  onTap: () => _abrirVideo(item, todosItens),
                                ),
                          const Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: AppTheme.corDivisor),
                        ],
                      );
                    },
                    childCount: itens.length,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  PopupMenuItem<Ordenacao> _menuItem(
      Ordenacao v, String label, IconData icon) {
    final ativo = _ordenacao == v;
    return PopupMenuItem(
      value: v,
      child: Row(children: [
        Icon(icon,
            color: ativo ? AppTheme.corPrimaria : AppTheme.corTextoMudo,
            size: 18),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: ativo ? AppTheme.corPrimaria : AppTheme.corTexto)),
      ]),
    );
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }
}

// ── Seção Continuar Assistindo ────────────────
class _SecaoContinuar extends StatelessWidget {
  final List<Map<String, dynamic>> recentes;
  final MediaService service;
  final void Function(String path) onTap;
  final void Function(String path) onRemover;

  const _SecaoContinuar({
    required this.recentes,
    required this.service,
    required this.onTap,
    required this.onRemover,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Continuar Assistindo',
              style: TextStyle(
                  color: AppTheme.corTextoMudo,
                  fontSize: 11,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: recentes.length,
            itemBuilder: (ctx, i) {
              final item = recentes[i];
              final path = item['path'] as String;
              final nome = path.split('/').last;
              final segundos = item['segundos'] as int;
              final duracao = item['duracao'] as int;
              final progresso = duracao > 0 ? segundos / duracao : 0.0;

              return GestureDetector(
                onTap: () => onTap(path),
                onLongPress: () => _confirmarRemover(context, path, nome),
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF0D0D22),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(10)),
                          ),
                          child: const Center(
                            child: Icon(Icons.play_circle_outline,
                                color: AppTheme.corPrimaria, size: 32),
                          ),
                        ),
                      ),
                      LinearProgressIndicator(
                        value: progresso.clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFF2A2A4A),
                        valueColor: const AlwaysStoppedAnimation(
                            AppTheme.corPrimaria),
                        minHeight: 3,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.corTexto, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(color: AppTheme.corDivisor, height: 24),
      ],
    );
  }

  void _confirmarRemover(BuildContext context, String path, String nome) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Remover progresso',
            style: TextStyle(color: AppTheme.corTexto)),
        content: Text('Remover "$nome" da lista?',
            style: const TextStyle(color: AppTheme.corTextoMudo)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onRemover(path);
            },
            child: const Text('Remover',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ── Tile de pasta ─────────────────────────────
class _FolderTile extends StatelessWidget {
  final MediaItem item;
  const _FolderTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: const Color(0xFF1A2550),
            borderRadius: BorderRadius.circular(10)),
        child:
            const Icon(Icons.folder_rounded, color: AppTheme.corPrimaria),
      ),
      title: Text(item.name,
          style: const TextStyle(
              color: AppTheme.corTexto,
              fontSize: 14,
              fontWeight: FontWeight.w500)),
      trailing:
          const Icon(Icons.chevron_right, color: AppTheme.corTextoMudo),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              BrowserPage(path: item.path, title: item.name),
        ),
      ),
    );
  }
}

// ── Tile de vídeo ─────────────────────────────
class _VideoTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  const _VideoTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 72,
        height: 44,
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.play_arrow_rounded,
            color: AppTheme.corPrimaria, size: 28),
      ),
      title: Text(item.name,
          style: const TextStyle(
              color: AppTheme.corTexto,
              fontSize: 13,
              fontWeight: FontWeight.w500),
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [item.tamanhoFormatado, item.extensao]
            .where((s) => s.isNotEmpty)
            .join(' · '),
        style:
            const TextStyle(color: AppTheme.corTextoMudo, fontSize: 11),
      ),
      onTap: onTap,
    );
  }
}