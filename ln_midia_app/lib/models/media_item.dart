class MediaItem {
  final String name;
  final String path;
  final String type;
  final int size;

  const MediaItem({
    required this.name,
    required this.path,
    required this.type,
    required this.size,
  });

  bool get isFolder => type == 'folder';

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        name: json['name'] as String,
        path: json['path'] as String,
        type: json['type'] as String,
        size: (json['size'] as num).toInt(),
      );

  String get tamanhoFormatado {
    if (size <= 0) return '';
    if (size > 1e9) return '${(size / 1e9).toStringAsFixed(1)} GB';
    if (size > 1e6) return '${(size / 1e6).toStringAsFixed(0)} MB';
    return '${(size / 1e3).toStringAsFixed(0)} KB';
  }

  String get extensao {
    if (!name.contains('.')) return '';
    return name.split('.').last.toUpperCase();
  }
}
