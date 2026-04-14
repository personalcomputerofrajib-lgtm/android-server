import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String _status = 'Type to search...';

  Future<void> _search(String query) async {
    if (query.length < 2) return;
    setState(() { _loading = true; _status = 'Searching...'; });

    try {
      final data = await ApiService.searchFiles(query);
      setState(() {
        _results = List<Map<String, dynamic>>.from(data['results'] ?? []);
        _status = '${_results.length} results for "$query"';
        _loading = false;
      });
    } catch (e) {
      setState(() { _status = 'Error: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search files...',
            hintStyle: TextStyle(color: Colors.grey),
            border: InputBorder.none,
          ),
          onChanged: (v) {
            if (v.length >= 2) _search(v);
          },
          onSubmitted: _search,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: () {
            _searchCtl.clear();
            setState(() { _results = []; _status = 'Type to search...'; });
          }),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(_status, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final item = _results[i];
                final isDir = item['is_dir'] ?? false;
                return ListTile(
                  leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file,
                    color: isDir ? Colors.blue : Colors.grey),
                  title: Text(item['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(item['path'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(context),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
