import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/progresso_service.dart';
import '../models/media_item.dart';

class PlayerPage extends StatefulWidget {
  final String title;
  final String url;
  final String path;
  final List<MediaItem> playlist;
  final int indiceAtual;

  const PlayerPage({
    required this.title,
    required this.url,
    required this.path,
    this.playlist = const [],
    this.indiceAtual = 0,
    super.key,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  Timer? _salvarTimer;
  Timer? _overlayTimer;

  Tracks? _tracks;
  bool _landscape = false;

  double _gestureStartY = 0;
  double _gestureStartValue = 0;
  bool _gestureEsquerda = false;
  double _volume = 1.0;
  String? _overlayMsg;

  static const _kIdiomaAudio = 'preferencia_idioma_audio';

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _player = Player();
    _controller = VideoController(_player);
    _iniciar();
  }

  Future<void> _iniciar() async {
    await _player.open(Media(widget.url));

    _player.stream.tracks.listen((t) async {
      if (!mounted) return;
      setState(() => _tracks = t);
      await _aplicarIdiomaPreferido(t.audio);
    });

    final posicao = await ProgressoService.carregar(widget.path);
    if (posicao > 0) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) await _player.seek(Duration(seconds: posicao));
    }

    _salvarTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final pos = _player.state.position.inSeconds;
      final dur = _player.state.duration.inSeconds;
      if (dur > 0) await ProgressoService.salvar(widget.path, pos, dur);
    });

    _player.stream.completed.listen((concluido) async {
      if (!concluido || !mounted) return;
      await ProgressoService.remover(widget.path);
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      _proximoEpisodio();
    });
  }

  Future<void> _aplicarIdiomaPreferido(List<AudioTrack> tracks) async {
    if (tracks.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final idiomaSalvo = prefs.getString(_kIdiomaAudio);
    if (idiomaSalvo == null) return;

    final trackPreferida = tracks.firstWhere(
      (t) =>
          (t.language?.toLowerCase().contains(idiomaSalvo) ?? false) ||
          (t.title?.toLowerCase().contains(idiomaSalvo) ?? false),
      orElse: () => AudioTrack.auto(),
    );

    if (trackPreferida.id != AudioTrack.auto().id) {
      await _player.setAudioTrack(trackPreferida);
    }
  }

  Future<void> _salvarIdiomaPreferido(AudioTrack t) async {
    final idioma = t.language?.toLowerCase() ?? t.title?.toLowerCase();
    if (idioma == null || idioma.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kIdiomaAudio, idioma);
  }

  void _alternarRotacao() {
    setState(() => _landscape = !_landscape);
    if (_landscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  String _buildUrl(String path) {
    final baseUrl = widget.url.split('/api/media/stream').first;
    return '$baseUrl/api/media/stream?path=${Uri.encodeComponent(path)}';
  }

  void _irParaEpisodio(int indice) {
    if (indice < 0 || indice >= widget.playlist.length) return;
    final item = widget.playlist[indice];
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          title: item.name,
          url: _buildUrl(item.path),
          path: item.path,
          playlist: widget.playlist,
          indiceAtual: indice,
        ),
      ),
    );
  }

  void _proximoEpisodio() {
    if (widget.playlist.isEmpty) return;
    final proximo = widget.indiceAtual + 1;
    if (proximo >= widget.playlist.length) return;
    final item = widget.playlist[proximo];

    bool cancelado = false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Próximo: ${item.name}'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Cancelar',
          onPressed: () => cancelado = true,
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted || cancelado) return;
      _irParaEpisodio(proximo);
    });
  }

  void _onGestureStart(DragStartDetails d) {
    final largura = MediaQuery.of(context).size.width;
    _gestureEsquerda = d.globalPosition.dx < largura / 2;
    _gestureStartY = d.globalPosition.dy;
    _gestureStartValue = _volume;
  }

  void _onGestureUpdate(DragUpdateDetails d) {
    final altura = MediaQuery.of(context).size.height;
    final delta = (_gestureStartY - d.globalPosition.dy) / altura;
    final novo = (_gestureStartValue + delta).clamp(0.0, 1.0);

    if (!_gestureEsquerda) {
      setState(() {
        _volume = novo;
        _overlayMsg = '🔊 ${(novo * 100).toInt()}%';
      });
      _player.setVolume(novo * 100);
    } else {
      setState(() {
        _overlayMsg = '☀️ ${(novo * 100).toInt()}%';
      });
    }

    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _overlayMsg = null);
    });
  }

  void _mostrarAudio() {
    final tracks = (_tracks?.audio ?? [])
        .where((t) => t.language != null || t.title != null)
        .toList()
      ..sort((a, b) {
        final aEhPor = (a.language?.contains('por') ?? false) ? 0 : 1;
        final bEhPor = (b.language?.contains('por') ?? false) ? 0 : 1;
        return aEhPor.compareTo(bEhPor);
      });
    if (tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aguarde o vídeo carregar as trilhas...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final selected = _player.state.track.audio;
    _mostrarSheet(
      titulo: 'Áudio',
      builder: () => _listaItens(tracks.map((t) {
        final label = t.language ?? t.title ?? '';
        return _TrackItem(
          label: label.toUpperCase(),
          ativo: t.id == selected.id,
          onTap: () async {
            _player.setAudioTrack(t);
            await _salvarIdiomaPreferido(t);
            if (mounted) Navigator.pop(context);
          },
        );
      }).toList()),
    );
  }

  void _mostrarLegendas() {
    final tracks = (_tracks?.subtitle ?? [])
        .where((t) => t.language != null || t.title != null)
        .toList();
    final selected = _player.state.track.subtitle;
    final desativada = SubtitleTrack.no();
    _mostrarSheet(
      titulo: 'Legendas',
      builder: () => _listaItens([
        _TrackItem(
          label: 'Desativada',
          ativo: selected.id == desativada.id,
          onTap: () { _player.setSubtitleTrack(desativada); Navigator.pop(context); },
        ),
        ...tracks.map((t) {
          final label = t.language ?? t.title ?? '';
          return _TrackItem(
            label: label.toUpperCase(),
            ativo: t.id == selected.id,
            onTap: () { _player.setSubtitleTrack(t); Navigator.pop(context); },
          );
        }),
      ]),
    );
  }

  void _mostrarVelocidade() {
    final velocidades = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final atual = _player.state.rate;
    _mostrarSheet(
      titulo: 'Velocidade',
      builder: () => _listaItens(velocidades.map((v) => _TrackItem(
        label: '${v}x',
        ativo: atual == v,
        onTap: () { _player.setRate(v); Navigator.pop(context); },
      )).toList()),
    );
  }

  void _mostrarSheet({required String titulo, required Widget Function() builder}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(titulo,
                style: const TextStyle(
                    color: AppTheme.corTexto,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
          const Divider(color: AppTheme.corDivisor, height: 1),
          builder(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _listaItens(List<_TrackItem> itens) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: itens.map((item) => ListTile(
        leading: Icon(
          item.ativo ? Icons.radio_button_checked : Icons.radio_button_off,
          color: item.ativo ? AppTheme.corPrimaria : AppTheme.corTextoMudo,
        ),
        title: Text(item.label,
            style: TextStyle(
              color: item.ativo ? AppTheme.corPrimaria : AppTheme.corTexto,
              fontWeight: item.ativo ? FontWeight.w600 : FontWeight.normal,
            )),
        onTap: item.onTap,
      )).toList(),
    );
  }

  @override
  void dispose() {
    _salvarTimer?.cancel();
    _overlayTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _player.dispose();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  final temAnterior = widget.playlist.isNotEmpty && widget.indiceAtual > 0;
  final temProximo = widget.playlist.isNotEmpty &&
      widget.indiceAtual + 1 < widget.playlist.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title,
            style: const TextStyle(color: AppTheme.corTexto, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        iconTheme: const IconThemeData(color: AppTheme.corPrimaria),
        actions: [
          if (_tracks == null)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: AppTheme.corPrimaria,
                  strokeWidth: 2,
                ),
              ),
            ),
          // Botão episódio anterior
          if (temAnterior)
            IconButton(
              icon: const Icon(Icons.skip_previous),
              tooltip: 'Episódio anterior',
              onPressed: () => _irParaEpisodio(widget.indiceAtual - 1),
            ),
          // Botão próximo episódio
          if (temProximo)
            IconButton(
              icon: const Icon(Icons.skip_next),
              tooltip: 'Próximo episódio',
              onPressed: () => _irParaEpisodio(widget.indiceAtual + 1),
            ),
          IconButton(
            icon: Icon(
              _landscape
                  ? Icons.screen_lock_portrait
                  : Icons.screen_lock_landscape,
            ),
            tooltip: _landscape ? 'Modo retrato' : 'Modo paisagem',
            onPressed: _alternarRotacao,
          ),
          IconButton(icon: const Icon(Icons.speed), tooltip: 'Velocidade', onPressed: _mostrarVelocidade),
          IconButton(icon: const Icon(Icons.language), tooltip: 'Áudio', onPressed: _mostrarAudio),
          IconButton(icon: const Icon(Icons.subtitles_outlined), tooltip: 'Legendas', onPressed: _mostrarLegendas),
        ],
      ),
      body: GestureDetector(
        onVerticalDragStart: _onGestureStart,
        onVerticalDragUpdate: _onGestureUpdate,
        child: Stack(
          children: [
            Center(child: Video(controller: _controller, controls: AdaptiveVideoControls)),
              // Botões flutuantes em landscape
      if (_landscape && temAnterior)
        Positioned(
          left: 8,
          top: 8,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.skip_previous, color: Colors.white),
              onPressed: () => _irParaEpisodio(widget.indiceAtual - 1),
            ),
          ),
        ),
      if (_landscape && temProximo)
        Positioned(
          left: temAnterior ? 56 : 8,
          top: 8,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.skip_next, color: Colors.white),
              onPressed: () => _irParaEpisodio(widget.indiceAtual + 1),
            ),
          ),
        ),
            if (_overlayMsg != null)
              Positioned(
                top: 20, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_overlayMsg!,
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrackItem {
  final String label;
  final bool ativo;
  final VoidCallback onTap;
  const _TrackItem({required this.label, required this.ativo, required this.onTap});
}