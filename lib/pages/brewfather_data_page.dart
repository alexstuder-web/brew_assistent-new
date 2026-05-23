import 'package:flutter/material.dart';
import '../services/brewfather_service.dart';

class BrewfatherDataPage extends StatefulWidget {
  const BrewfatherDataPage({
    super.key,
    required this.userId,
    required this.apiKey,
    required this.dataType, // 'recipes', 'batches', 'inventory'
  });

  final String userId;
  final String apiKey;
  final String dataType;

  @override
  State<BrewfatherDataPage> createState() => _BrewfatherDataPageState();
}

class _BrewfatherDataPageState extends State<BrewfatherDataPage> {
  late final BrewfatherService _service;
  late Future<dynamic> _dataFuture;

  @override
  void initState() {
    super.initState();
    _service = BrewfatherService();
    _loadData();
  }

  void _loadData() {
    switch (widget.dataType) {
      case 'recipes':
        _dataFuture = _service.getRecipes();
        break;
      case 'batches':
        _dataFuture = _service.getBatches();
        break;
      case 'inventory':
        _dataFuture = _service.getInventory();
        break;
      default:
        _dataFuture = Future.error('Unbekannter Datentyp');
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = '';
    switch (widget.dataType) {
      case 'recipes': title = 'Rezepte'; break;
      case 'batches': title = 'Batches'; break;
      case 'inventory': title = 'Inventar'; break;
    }

    return Scaffold(
      appBar: AppBar(title: Text('Brewfather $title')),
      body: FutureBuilder<dynamic>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          } else if (!snapshot.hasData || (snapshot.data is List && (snapshot.data as List).isEmpty)) {
            return const Center(child: Text('Keine Daten gefunden.'));
          }

          final data = snapshot.data;

          if (widget.dataType == 'inventory') {
            return _buildInventoryList(data as Map<String, List<dynamic>>);
          } else {
            return _buildStandardList(data as List<dynamic>);
          }
        },
      ),
    );
  }

  Widget _buildStandardList(List<dynamic> items) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final name = item['name'] ?? 'Unbenannt';
        final style = item['style']?['name'] ?? ''; // Safely access nested style name
        final type = item['type'] ?? '';

        return Card(
          child: ListTile(
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$style $type'),
            // Bei Bedarf mehr Details anzeigen
            onTap: () {
               showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(name),
                  content: SingleChildScrollView(
                    child: Text(item.toString()), // Primitive Detail-Ansicht
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInventoryList(Map<String, List<dynamic>> inventory) {
    return ListView(
      children: inventory.entries.map((entry) {
        final category = entry.key.toUpperCase();
        final items = entry.value;

        return ExpansionTile(
          title: Text('$category (${items.length})'),
          children: items.map<Widget>((item) {
             final name = item['name'] ?? 'Unbenannt';
             final amount = item['inventory'] ?? 0;
             final unit = item['unit'] ?? '';

             return ListTile(
               title: Text(name),
               trailing: Text('$amount $unit'),
             );
          }).toList(),
        );
      }).toList(),
    );
  }
}
