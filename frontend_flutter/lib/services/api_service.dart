import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Change this to your backend IP
  static const String baseUrl = 'http://127.0.0.1:8000';

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
    final res = await http.get(uri);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getFileInfo(String path) async {
    final uri = Uri.parse('$baseUrl/api/files/info').replace(
      queryParameters: {'path': path},
    );
    final res = await http.get(uri);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> readFile(String path) async {
    final uri = Uri.parse('$baseUrl/api/files/read').replace(
      queryParameters: {'path': path},
    );
    final res = await http.get(uri);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> writeFile(String path, String content) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/files/write'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'path': path, 'content': content}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createFolder(String path, String name) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/files/create-folder'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'path': path, 'name': name}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createFile(String path, String name, {String content = ''}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/files/create-file'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'path': path, 'name': name, 'content': content}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> deleteItem(String path) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/files/delete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'path': path}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> renameItem(String path, String newName) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/files/rename'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'path': path, 'new_name': newName}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> copyItem(String path) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/files/copy'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'path': path}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> cutItem(String path) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/files/cut'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'path': path}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> pasteItem(String destination) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/files/paste'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'destination': destination}),
    );
    return jsonDecode(res.body);
  }

  // ==================== SEARCH ====================

  static Future<Map<String, dynamic>> searchFiles(String query, {String? root}) async {
    final params = {'q': query};
    if (root != null) params['root'] = root;
    final uri = Uri.parse('$baseUrl/api/search').replace(queryParameters: params);
    final res = await http.get(uri);
    return jsonDecode(res.body);
  }

  // ==================== STORAGE ====================

  static Future<Map<String, dynamic>> getStorageInfo() async {
    final res = await http.get(Uri.parse('$baseUrl/api/storage'));
    return jsonDecode(res.body);
  }

  // ==================== TERMINAL ====================

  static Future<Map<String, dynamic>> executeCommand(String command) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/terminal/execute'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'command': command}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> killProcess() async {
    final res = await http.post(Uri.parse('$baseUrl/api/terminal/kill'));
    return jsonDecode(res.body);
  }

  static Future<List<String>> getAutocomplete(String partial) async {
    final uri = Uri.parse('$baseUrl/api/terminal/autocomplete').replace(
      queryParameters: {'q': partial},
    );
    final res = await http.get(uri);
    final data = jsonDecode(res.body);
    return List<String>.from(data['suggestions'] ?? []);
  }

  static Future<Map<String, dynamic>> getTerminalCwd() async {
    final res = await http.get(Uri.parse('$baseUrl/api/terminal/cwd'));
    return jsonDecode(res.body);
  }

  // ==================== SERVERS ====================

  static Future<Map<String, dynamic>> listServers() async {
    final res = await http.get(Uri.parse('$baseUrl/api/servers'));
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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> stopServer(String sid) async {
    final res = await http.post(Uri.parse('$baseUrl/api/servers/$sid/stop'));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> restartServer(String sid) async {
    final res = await http.post(Uri.parse('$baseUrl/api/servers/$sid/restart'));
    return jsonDecode(res.body);
  }

  static Future<List<String>> getServerLogs(String sid, {int n = 50}) async {
    final uri = Uri.parse('$baseUrl/api/servers/$sid/logs').replace(
      queryParameters: {'n': n.toString()},
    );
    final res = await http.get(uri);
    final data = jsonDecode(res.body);
    return List<String>.from(data['logs'] ?? []);
  }

  static Future<Map<String, dynamic>> stopAllServers() async {
    final res = await http.post(Uri.parse('$baseUrl/api/servers/stop-all'));
    return jsonDecode(res.body);
  }

  // ==================== HEALTH ====================

  static Future<bool> checkHealth() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
