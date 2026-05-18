import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LegacyRecipeResultPage extends StatelessWidget {
  const LegacyRecipeResultPage({
    super.key,
    required this.prompt,
    required this.response,
  });

  final String prompt;
  final String response;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rezept (Legacy)')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LegacyRecipeDisplayPage(
                    jsonResponse: response,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long),
            label: const Text('Rezept darstellen'),
          ),
          const SizedBox(height: 24),
          Text(
            'Abgeschickter Prompt',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF0F172A),
              border: Border.all(color: Colors.white12),
            ),
            child: SelectableText(prompt),
          ),
          const SizedBox(height: 24),
          Text(
            'Antwort (JSON)',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF0F172A),
              border: Border.all(color: Colors.white12),
            ),
            child: SelectableText(response),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class LegacyRecipeDisplayPage extends StatelessWidget {
  const LegacyRecipeDisplayPage({super.key, required this.jsonResponse});

  final String jsonResponse;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? parsed;
    try {
      final cleaned = _extractJson(jsonResponse);
      parsed = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      parsed = null;
    }

    final basisBier = _stringField(parsed?['basis_bier']);
    final bierTyp = _stringField(parsed?['bier_typ']);
    final title = (basisBier != null && bierTyp != null)
        ? 'Dein Bier Rezept für ein $basisBier im Stile eines $bierTyp'
        : 'Dein Bier Rezept';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: parsed == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: const Text(
                  'Antwort konnte nicht als JSON gelesen werden.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ..._buildSections(parsed),
              ],
            ),
    );
  }

  List<Widget> _buildSections(Map<String, dynamic> parsed) {
    final zutaten = _asMap(parsed['Zutaten'] ?? parsed['zutaten']);
    final prozess = _asMap(parsed['Prozessdaten'] ?? parsed['prozessdaten']);
    final sections = <Widget>[];

    void addSection(String title, List<_RecipeEntry> entries) {
      if (sections.isNotEmpty) {
        sections.add(const Divider(height: 32, color: Colors.white24));
      }
      sections.add(_RecipeSection(title: title, entries: entries));
    }

    addSection(
      'Zutaten – Malz',
      _formatList(zutaten['Original_Malz'] ?? zutaten['original_malz']),
    );
    addSection(
      'Zutaten – Hopfen',
      _formatList(zutaten['Original_Hopfen'] ?? zutaten['original_hopfen']),
    );
    addSection(
      'Zutaten – Hefe',
      _formatList(zutaten['Original_Hefe'] ?? zutaten['original_hefe']),
    );
    addSection(
      'Spezialzutaten',
      _formatList(zutaten['Spezialzutaten'] ?? zutaten['spezialzutaten']),
    );
    addSection(
      'Klär- & Schönungsmittel',
      _formatList(
        zutaten['Klaer_und_Schonungsmittel'] ??
            zutaten['klaer_und_schonungsmittel'],
      ),
    );
    addSection(
      'Wasseraufbereitung',
      _formatList(
        zutaten['Wasseraufbereitung'] ?? zutaten['wasseraufbereitung'],
      ),
    );
    addSection(
      'Maischeplan',
      _formatList(prozess['Maischeplan'] ?? prozess['maischeplan']),
    );
    addSection(
      'Kochplan',
      _formatKochplan(
        prozess['Kochzeit_und_Kochphasen'] ?? prozess['kochzeit_und_kochphasen'],
      ),
    );
    addSection(
      'Gärplan',
      _formatGaerplan(
        prozess['Gaerplan'] ?? prozess['Gärplan'] ?? prozess['gaerplan'],
      ),
    );
    addSection(
      'Abfüllung & Lagern',
      _formatList(
        prozess['Abfuellung_ins_Keg'] ?? prozess['abfuellung_ins_keg'],
      ),
    );
    addSection(
      'Abfüllung – Flaschen',
      _formatList(
        prozess['Abfuellung_in_Flaschen'] ?? prozess['abfuellung_in_flaschen'],
      ),
    );
    addSection(
      'Notizen',
      _formatList(parsed['Notizen'] ?? parsed['notizen']),
    );

    return sections;
  }

  List<_RecipeEntry> _formatList(dynamic input) {
    if (input == null) return [const _RecipeEntry(text: 'Keine Angaben')];
    if (input is List) {
      if (input.isEmpty) return [const _RecipeEntry(text: 'Keine Angaben')];
      return input.map((e) => _formatEntry(e)).toList();
    }
    return [_formatEntry(input)];
  }

  List<_RecipeEntry> _formatKochplan(dynamic input) {
    if (input == null) return [const _RecipeEntry(text: 'Keine Angaben')];
    if (input is Map<String, dynamic>) {
      final lines = <_RecipeEntry>[];
      if (input['Gesamte_Kochdauer'] != null) {
        lines
            .add(_entry('Gesamte Kochdauer: ${input['Gesamte_Kochdauer']} min'));
      }
      if (input['Kochphasen'] != null) {
        lines.add(_entry('Kochphasen:'));
        lines.addAll(
          _prefixEntries(_formatList(input['Kochphasen']), '  - '),
        );
      }
      if (input['Hopfengaben'] != null) {
        lines.add(_entry('Hopfengaben:'));
        lines.addAll(
          _prefixEntries(_formatList(input['Hopfengaben']), '  - '),
        );
      }
      if (input['Erwartete_Gravity_nach_Kochen'] != null) {
        lines.add(_entry(
            'Erw. Gravity nach Kochen: ${input['Erwartete_Gravity_nach_Kochen']}'));
      }
      if (input['Erwarteter_pH_Wert_nach_Kochen'] != null) {
        lines.add(_entry(
            'Erw. pH nach Kochen: ${input['Erwarteter_pH_Wert_nach_Kochen']}'));
      }
      return lines.isEmpty ? [const _RecipeEntry(text: 'Keine Angaben')] : lines;
    }
    return _formatList(input);
  }

  List<_RecipeEntry> _formatGaerplan(dynamic input) {
    if (input == null) return [const _RecipeEntry(text: 'Keine Angaben')];
    if (input is Map<String, dynamic>) {
      final lines = <_RecipeEntry>[];
      if (input['Empfehlung'] != null) {
        lines.add(_entry('Empfehlung: ${input['Empfehlung']}'));
      }
      if (input['Gaerphase'] != null) {
        final phases = input['Gaerphase'];
        final iterable = phases is List ? phases : [phases];
        for (final phase in iterable) {
          if (phase is Map) {
            final phaseMap =
                phase.map((key, value) => MapEntry(key.toString(), value));
            final name = phaseMap.remove('Name') ?? phaseMap.remove('name');
            final details = _formatEntry(phaseMap).text;
            final label = name ?? 'Phase';
            lines.add(_entry('$label: $details'));
          } else {
            lines.add(_entry(phase.toString()));
          }
        }
      }
      return lines.isEmpty ? [const _RecipeEntry(text: 'Keine Angaben')] : lines;
    }
    return _formatList(input);
  }

  _RecipeEntry _formatEntry(dynamic value) {
    if (value == null) return const _RecipeEntry(text: 'Keine Angaben');
    if (value is String) {
      final trimmed = value.trim();
      return _RecipeEntry(text: trimmed.isEmpty ? 'Keine Angaben' : trimmed);
    }
    if (value is Map) {
      final normalized = value.map((key, val) => MapEntry(key.toString(), val));
      final url = _extractUrlField(normalized);
      final parts = <String>[];
      normalized.forEach((key, val) {
        if (_isUrlKey(key)) return;
        parts.add('${_beautifyKey(key)}: ${_formatSimpleValue(val)}');
      });
      final text = parts.isEmpty ? (url ?? 'Keine Angaben') : parts.join(', ');
      return _RecipeEntry(text: text, link: url);
    }
    return _RecipeEntry(text: value.toString());
  }

  String _formatSimpleValue(dynamic value) {
    if (value == null) return 'Keine Angaben';
    if (value is Map || value is List) {
      final entry = _formatEntry(value);
      return entry.link != null && entry.link!.isNotEmpty
          ? '${entry.text} (${entry.link})'
          : entry.text;
    }
    if (value is String && value.trim().isEmpty) return 'Keine Angaben';
    return value.toString();
  }

  _RecipeEntry _entry(String text) => _RecipeEntry(text: text);

  List<_RecipeEntry> _prefixEntries(List<_RecipeEntry> entries, String prefix) {
    return entries
        .map(
          (entry) => entry.copyWith(text: '$prefix${entry.text}'),
        )
        .toList();
  }

  String? _extractUrlField(Map<String, dynamic> map) {
    for (final entry in map.entries) {
      if (_isUrlKey(entry.key)) {
        final value = entry.value;
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  bool _isUrlKey(String key) {
    final lower = key.toLowerCase();
    return lower == 'url' || lower.endsWith('_url') || lower.contains('link');
  }

  String _beautifyKey(String key) {
    return key.replaceAll('_', ' ');
  }

  String? _stringField(dynamic value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  String _extractJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('```')) {
      final endFence = trimmed.lastIndexOf('```');
      if (endFence > 3) {
        final body = trimmed.substring(3, endFence).trim();
        final firstNewline = body.indexOf('\n');
        if (body.startsWith('json') && firstNewline != -1) {
          return body.substring(firstNewline + 1).trim();
        }
        return body;
      }
    }
    return trimmed;
  }
}

class _RecipeSection extends StatelessWidget {
  const _RecipeSection({required this.title, required this.entries});

  final String title;
  final List<_RecipeEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...entries.map((entry) => _RecipeLine(entry: entry)),
      ],
    );
  }
}

class _RecipeLine extends StatelessWidget {
  const _RecipeLine({required this.entry});

  final _RecipeEntry entry;

  @override
  Widget build(BuildContext context) {
    final defaultStyle = Theme.of(context).textTheme.bodyMedium;
    final linkStyle = defaultStyle?.copyWith(
      color: const Color(0xFF38BDF8),
      decoration: TextDecoration.underline,
    );
    final segments = _segmentLine(entry.text);
    final List<Widget> children = <Widget>[];
    for (final segment in segments) {
      final textWidget = Text(
        segment.text,
        style: segment.isLink ? linkStyle : defaultStyle,
      );
      if (!segment.isLink) {
        children.add(textWidget);
        continue;
      }
      children.add(
        GestureDetector(
          onTap: () => _launchExternalUrl(segment.text),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: textWidget,
          ),
        ),
      );
    }

    final linkText = entry.link?.trim();
    if (linkText != null && linkText.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: 6));
      }
      children.add(
        GestureDetector(
          onTap: () => _launchExternalUrl(linkText),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Text(
              linkText,
              style: linkStyle,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }

  static final RegExp _urlRegExp =
      RegExp(r'(https?:\/\/[^\s)]+)', caseSensitive: false);

  Future<void> _launchExternalUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    Uri? uri = Uri.tryParse(trimmed);
    if (uri == null) return;
    if (!uri.hasScheme) {
      uri = Uri.tryParse('https://$trimmed');
      if (uri == null) return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Ignore launch errors
    }
  }

  List<_LinkSegment> _segmentLine(String line) {
    final matches = _urlRegExp.allMatches(line);
    if (matches.isEmpty) {
      return [_LinkSegment(line, false)];
    }
    final segments = <_LinkSegment>[];
    var currentIndex = 0;
    for (final match in matches) {
      if (match.start > currentIndex) {
        segments.add(
          _LinkSegment(line.substring(currentIndex, match.start), false),
        );
      }
      final url = match.group(0);
      if (url != null && url.isNotEmpty) {
        segments.add(_LinkSegment(url, true));
      }
      currentIndex = match.end;
    }
    if (currentIndex < line.length) {
      segments.add(_LinkSegment(line.substring(currentIndex), false));
    }
    return segments.isEmpty ? [_LinkSegment(line, false)] : segments;
  }
}

class _LinkSegment {
  const _LinkSegment(this.text, this.isLink);

  final String text;
  final bool isLink;
}

class _RecipeEntry {
  const _RecipeEntry({required this.text, this.link});

  final String text;
  final String? link;

  _RecipeEntry copyWith({String? text, String? link}) {
    return _RecipeEntry(
      text: text ?? this.text,
      link: link ?? this.link,
    );
  }
}
