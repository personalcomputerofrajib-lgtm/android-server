import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // ==================== SMART URL DETECTION ====================
  // Auto-detects the correct backend URL based on platform:
  //   - Android Emulator: 10.0.2.2 (maps to host's localhost)
  //   - Real device / other: uses configurable IP
  //
  // To connect a REAL phone to your PC backend:
  //   1. Make sure phone and PC are on same WiFi
  //   2. Set _manualIp to your PC's local IP (e.g. '192.168.1.100')
  //   3. Or keep null for auto-detection

  static String? _manualIp;  // Set to your PC IP for real device, e.g. '192.168.1.100'
  static const int _port = 8000;

  // API Key for basic authentication (must match backend)
  static const String _apiKey = 'fmpro_2024_secure_key';

  static String get baseUrl {
    if (_manualIp != null) {
      return 'http://$_manualIp:$_port';
    }
    // Auto-detect platform
    try {
      if (Platform.isAndroid) {
        // Check if running on emulator (10.0.2.2 routes to host localhost)
        // On real device, user MUST set _manualIp above
        return 'http://10.0.2.2:$_port';
      }
    } catch (_) {}
    // Desktop / iOS simulator / web fallback
    return 'http://127.0.0.1:$_port';
  }

  /// Call this from Settings screen to change backend IP at runtime
  static void setBackendIp(String ip) {
    _manualIp = ip.trim().isEmpty ? null : ip.trim();
  }

  /// Get currently configured backend URL
  static String get currentUrl => baseUrl;

  // ==================== AUTH HEADERS ====================

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-API-Key': _apiKey,
  };

  static Map<String, String> get _authOnlyHeaders => {
    'X-API-Key': _apiKey,
  };

  // ==================== FILES ====================

  static Future<Map<String, dynamic>> listFiles({
    required String path,
    bool showHidden = false,
    String sortBy = 'name',
  }) async {
    final uri = Uri.parse('$baseUrl/api/files').replace(queryParameters: {
      'path': path,
      'hidden': showHidden.toString(),
      'sort': sortBy,
    });
    final res = await http.get(uri, headers: _authOnlyHeaders);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getFileInfo(String path) async {
    final uri = Uri.parse('$baseUrl/api/files/info').replace(
      queryParameters: {'path': path},
    );
    final res = await http.get(uri, headers: _authOnlyHeaders);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> readFile(String path) async {
    final uri = Uri.parse('$baseUrl/api/files/read').replace(
      queryParameters: {'path': path},
    );
    final res = await http.get(uri, headers: _authOnlyHeaders);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> writeFile(String path, String content) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/files/write'),
      headers: _headers,
      body: jsonEncode({'path': path, 'content': content}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createFolder(String path, String name) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/files/create-folder'),
      headers: _headers,
      body: jsonEncode({'path': path, 'name': name}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createFile(String path, String name, {String content = ''}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/files/create-file'),
      headers: _headers,
      body: jsonEncode({'path': path, 'name': name, 'content': content}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> deleteItem(String path) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/files/delete'),
      headers: _headers,
      body: jsonEncode({'path': path}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> renameItem(String path, String newName) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/files/rename'),
      headers: _headers,
      body: jsonEncode({'path': path, 'new_name': newName}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> copyItem(String path) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/files/copy'),
      headers: _headers,
      body: jsonEncode({'path': path}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> cutItem(String path) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/files/cut'),
      headers: _headers,
      body: jsonEncode({'path': path}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> pasteItem(String destination) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/files/paste'),
      headers: _headers,
      body: jsonEncode({'destination': destination}),
    );
    return jsonDecode(res.body);
  }

  // ==================== SEARCH ====================

  static Future<Map<String, dynamic>> searchFiles(String query, {String? root}) async {
    final params = {'q': query};
    if (root != null) params['root'] = root;
    final uri = Uri.parse('$baseUrl/api/search').replace(queryParameters: params);
    final res = await http.get(uri, headers: _authOnlyHeaders);
    return jsonDecode(res.body);
  }

  // ==================== STORAGE ====================

  static Future<Map<String, dynamic>> getStorageInfo() async {
    final res = await http.get(Uri.parse('$baseUrl/api/storage'), headers: _authOnlyHeaders);
    return jsonDecode(res.body);
  }

  // ==================== TERMINAL ====================

  static Future<Map<String, dynamic>> executeCommand(String command) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/terminal/execute'),
      headers: _headers,
      body: jsonEncode({'command': command}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> killProcess() async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/terminal/kill'),
      headers: _authOnlyHeaders,
    );
    return jsonDecode(res.body);
  }

  static Future<List<String>> getAutocomplete(String partial) async {
    final uri = Uri.parse('$baseUrl/api/terminal/autocomplete').replace(
      queryParameters: {'q': partial},
    );
    final res = await http.get(uri, headers: _authOnlyHeaders);
    final data = jsonDecode(res.body);
    return List<String>.from(data['suggestions'] ?? []);
  }

  static Future<Map<String, dynamic>> getTerminalCwd() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/terminal/cwd'),
      headers: _authOnlyHeaders,
    );
    return jsonDecode(res.body);
  }

  // ==================== SERVERS ====================

  static Future<Map<String, dynamic>> listServers() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/servers'),
      headers: _authOnlyHeaders,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> startServer({
    required String type,
    required String directory,
    int port = 8000,
    String? command,
    String? name,
    String? script,
  }) async {
    final body = <String, dynamic>{
      'type': type,
      'directory': directory,
      'port': port,
    };
    if (command != null) body['command'] = command;
    if (name != null) body['name'] = name;
    if (script != null) body['script'] = script;

    final res = await http.post(
      Uri.parse('$baseUrl/api/servers/start'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> stopServer(String sid) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/servers/$sid/stop'),
      headers: _authOnlyHeaders,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> restartServer(String sid) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/servers/$sid/restart'),
      headers: _authOnlyHeaders,
    );
    return jsonDecode(res.body);
  }

  static Future<List<String>> getServerLogs(String sid, {int n = 50}) async {
    final uri = Uri.parse('$baseUrl/api/servers/$sid/logs').replace(
      queryParameters: {'n': n.toString()},
    );
    final res = await http.get(uri, headers: _authOnlyHeaders);
    final data = jsonDecode(res.body);
    return List<String>.from(data['logs'] ?? []);
  }

  static Future<Map<String, dynamic>> stopAllServers() async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/servers/stop-all'),
      headers: _authOnlyHeaders,
    );
    return jsonDecode(res.body);
  }

  // ==================== HEALTH ====================

  static Future<bool> checkHealth() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/health'),
        headers: _authOnlyHeaders,
      ).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
