import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class ServerInfo {
  final String id;
  final String name;
  final String type;
  final int port;
  final String status;
  final int? pid;
  final String uptimeStr;
  final String directory;
  final String command;

  ServerInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.port,
    required this.status,
    this.pid,
    this.uptimeStr = '0s',
    this.directory = '',
    this.command = '',
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) {
    return ServerInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      port: json['port'] ?? 0,
      status: json['status'] ?? 'stopped',
      pid: json['pid'],
      uptimeStr: json['uptime_str'] ?? '0s',
      directory: json['directory'] ?? '',
      command: json['command'] ?? '',
    );
  }

  bool get isRunning => status == 'running';
  bool get isError => status == 'error';
}

class ServerProvider with ChangeNotifier {
  List<ServerInfo> _servers = [];
  List<String> _logs = [];
  String _localIp = '127.0.0.1';
  String? _selectedId;
  Timer? _timer;

  List<ServerInfo> get servers => _servers;
  List<String> get logs => _logs;
  String get localIp => _localIp;
  String? get selectedId => _selectedId;
  int get runningCount => _servers.where((s) => s.isRunning).length;

  ServerProvider() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final data = await ApiService.listServers();
      _localIp = data['local_ip'] ?? '127.0.0.1';
      final list = data['servers'] as List? ?? [];
      _servers = list.map((s) => ServerInfo.fromJson(s)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> startPythonHttp(String directory, int port) async {
    await ApiService.startServer(type: 'python_http', directory: directory, port: port);
    await refresh();
  }

  Future<void> startNpm(String directory, String script, int port) async {
    await ApiService.startServer(type: 'npm', directory: directory, port: port, script: script);
    await refresh();
  }

  Future<void> startCustom(String directory, String command, String name, int port) async {
    await ApiService.startServer(
      type: 'custom', directory: directory, port: port,
      command: command, name: name,
    );
    await refresh();
  }

  Future<void> stopServer(String sid) async {
    await ApiService.stopServer(sid);
    await refresh();
  }

  Future<void> restartServer(String sid) async {
    await ApiService.restartServer(sid);
    await refresh();
  }

  Future<void> stopAll() async {
    await ApiService.stopAllServers();
    await refresh();
  }

  Future<void> selectServer(String sid) async {
    _selectedId = sid;
    try {
      _logs = await ApiService.getServerLogs(sid);
    } catch (_) {
      _logs = ['Failed to load logs'];
    }
    notifyListeners();
  }
}
