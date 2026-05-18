import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/bf_batch.dart';

class JsonTab extends StatelessWidget {
  const JsonTab({super.key, required this.batch});

  final BfBatch batch;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children:
            batch.data.entries.map((e) => _JsonNode(e.key, e.value)).toList(),
      ),
    );
  }
}

class _JsonNode extends StatelessWidget {
  const _JsonNode(this.nodeKey, this.value);

  final String nodeKey;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    if (value is Map) {
      if ((value as Map).isEmpty) {
        return ListTile(
          title: Text('$nodeKey: {}',
              style: const TextStyle(fontFamily: 'monospace')),
          dense: true,
          contentPadding: EdgeInsets.zero,
        );
      }
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(nodeKey,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF66B342))),
          subtitle: Text('{ ... }',
              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(left: 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: (value as Map)
              .entries
              .map((e) => _JsonNode(e.key.toString(), e.value))
              .toList(),
        ),
      );
    } else if (value is List) {
      if ((value as List).isEmpty) {
        return ListTile(
          title: Text('$nodeKey: []',
              style: const TextStyle(fontFamily: 'monospace')),
          dense: true,
          contentPadding: EdgeInsets.zero,
        );
      }
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(nodeKey,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF66B342))),
          subtitle: Text('[${(value as List).length}]',
              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(left: 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: (value as List)
              .asMap()
              .entries
              .map((e) => _JsonNode('[${e.key}]', e.value))
              .toList(),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('$nodeKey: ',
                style: const TextStyle(color: Colors.grey)),
            Expanded(
              child: SelectableText(
                value.toString(),
                style: const TextStyle(
                    fontFamily: 'monospace', color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }
  }
}

class RawJsonTab extends StatelessWidget {
  const RawJsonTab({super.key, required this.batch});

  final BfBatch batch;

  @override
  Widget build(BuildContext context) {
    String prettyJson =
        const JsonEncoder.withIndent('  ').convert(batch.data);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        prettyJson,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}
