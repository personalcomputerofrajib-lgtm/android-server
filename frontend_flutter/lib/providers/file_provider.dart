import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FileItem {
  final String name;
  final String path;
  final bool isDir;
  final int size;
  final String modifiedStr;
  final String extension;
  final String permissions;
  final bool isSymlink;

  FileItem({
    required this.name,
    required this.path,
    required this.isDir,
    this.size = 0,
    this.modifiedStr = '',
    this.extension = '',
    this.permissions = '',
    this.isSymlink = false,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      isDir: json['is_dir'] ?? false,
      size: json['size'] ?? 0,
      modifiedStr: json['modified_str'] ?? '',
      extension: json['extension'] ?? '',
      permissions: json['permissions'] ?? '',
      isSymlink: json['is_symlink'] ?? false,
    );
  }

  String get sizeStr {
    if (isDir) return 'Folder';
    if (size == 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int idx = 0;
    double s = size.toDouble();
    while (s >= 1024 && idx < units.length - 1) {
      s /= 1024;
      idx++;
    }
    return '${s.toStringAsFixed(1)} ${units[idx]}';
  }

  IconData get icon {
    if (isDir) return _folderIcon;
    return _fileIcon;
  }

  IconData get _folderIcon {
    final n = name.toLowerCase();
    final map = {
      'downloads': Icons.download,
      'documents': Icons.description,
      'pictures': Icons.image,
      'music': Icons.music_note,
      'videos': Icons.video_library,
      'dcim': Icons.camera_alt,
      'android': Icons.android,
    };
    // Can't import Icons here, will use in widget
    return Icons.folder;
  }

  IconData get _fileIcon => Icons.insert_drive_file;
}

class FileProvider with ChangeNotifier {
  String _currentPath = '';
  List<FileItem> _items = [];
  bool _loading = false;
  String _error = '';
  bool _showHidden = false;
  String _sortBy = 'name';
  final List<String> _pathHistory = [];
  bool _hasClipboard = false;

  String get currentPath => _currentPath;
  List<FileItem> get items => _items;
  bool get loading => _loading;
  String get error => _error;
  bool get showHidden => _showHidden;
  String get sortBy => _sortBy;
  bool get hasClipboard => _hasClipboard;
  bool get canGoBack => _pathHistory.isNotEmpty || _currentPath.contains('/');

  int get folderCount => _items.where((i) => i.isDir).length;
  int get fileCount => _items.where((i) => !i.isDir).length;

  Future<void> loadDirectory([String? path]) async {
    _loading = true;
    _error = '';
    notifyListeners();

    try {
      final targetPath = path ?? _currentPath;
      final data = await ApiService.listFiles(
        path: targetPath,
        showHidden: _showHidden,
        sortBy: _sortBy,
      );

      if (data.containsKey('error')) {
        _error = data['error'];
      } else {
        if (path != null && path != _currentPath) {
          _pathHistory.add(_currentPath);
        }
        _currentPath = data['path'] ?? targetPath;
        final itemsList = data['items'] as List? ?? [];
        _items = itemsList.map((i) => FileItem.fromJson(i)).toList();
      }
    } catch (e) {
      _error = 'Connection error: $e';
    }

    _loading = false;
    notifyListeners();
  }

  void navigateTo(String path) => loadDirectory(path);

  void goBack() {
    if (_pathHistory.isNotEmpty) {
      final prev = _pathHistory.removeLast();
      loadDirectory(prev);
    } else {
      final parent = _currentPath.substring(0, _currentPath.lastIndexOf('/'));
      if (parent.isNotEmpty) loadDirectory(parent);
    }
  }

  void goHome() {
    _pathHistory.clear();
    _currentPath = '';
    loadDirectory();
  }

  void toggleHidden() {
    _showHidden = !_showHidden;
    loadDirectory(_currentPath);
  }

  void setSortBy(String sort) {
    _sortBy = sort;
    loadDirectory(_currentPath);
  }

  Future<Map<String, dynamic>> createFolder(String name) async {
    final result = await ApiService.createFolder(_currentPath, name);
    if (result['success'] == true) await loadDirectory(_currentPath);
    return result;
  }

  Future<Map<String, dynamic>> createFile(String name, {String content = ''}) async {
    final result = await ApiService.createFile(_currentPath, name, content: content);
    if (result['success'] == true) await loadDirectory(_currentPath);
    return result;
  }

  Future<Map<String, dynamic>> deleteItem(String path) async {
    final result = await ApiService.deleteItem(path);
    if (result['success'] == true) await loadDirectory(_currentPath);
    return result;
  }

  Future<Map<String, dynamic>> renameItem(String path, String newName) async {
    final result = await ApiService.renameItem(path, newName);
    if (result['success'] == true) await loadDirectory(_currentPath);
    return result;
  }

  Future<void> copyItem(String path) async {
    await ApiService.copyItem(path);
    _hasClipboard = true;
    notifyListeners();
  }

  Future<void> cutItem(String path) async {
    await ApiService.cutItem(path);
    _hasClipboard = true;
    notifyListeners();
  }

  Future<Map<String, dynamic>> pasteItem() async {
    final result = await ApiService.pasteItem(_currentPath);
    if (result['success'] == true) {
      _hasClipboard = false;
      await loadDirectory(_currentPath);
    }
    return result;
  }
}
