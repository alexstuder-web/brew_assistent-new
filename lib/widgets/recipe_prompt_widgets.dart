import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/openai_service.dart';

class ShopResultsSheet extends StatelessWidget {
  const ShopResultsSheet({super.key, required this.results});

  final List<ShopSearchResponse> results;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ListView.builder(
          controller: controller,
          itemCount: results.length,
          itemBuilder: (context, index) {
            final result = results[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ShopResultSection(result: result),
            );
          },
        ),
      ),
    );
  }
}

class ShopResultSection extends StatelessWidget {
  const ShopResultSection({super.key, required this.result});

  final ShopSearchResponse result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zutat: ${result.query}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...result.shops.map(
          (shop) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ShopCard(shop: shop),
          ),
        ),
      ],
    );
  }
}

class ShopCard extends StatelessWidget {
  const ShopCard({super.key, required this.shop});

  final ShopSearchShop shop;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF111827),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  shop.shop,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (shop.url != null)
                  TextButton(
                    onPressed: () => _launchShopLink(shop.url!),
                    child: const Text('Shop öffnen'),
                  ),
              ],
            ),
            if (shop.error != null)
              const Text(
                'Keine Ergebnisse automatisch verfügbar. Bitte Shop öffnen.',
                style: TextStyle(color: Colors.redAccent),
              )
            else if (shop.results.isEmpty)
              const Text(
                'Keine Treffer gefunden.',
                style: TextStyle(color: Colors.white70),
              )
            else
              ...shop.results.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if ((item.price ?? '').isNotEmpty)
                        Text(item.price!,
                            style: const TextStyle(color: Colors.white70)),
                      if ((item.availability ?? '').isNotEmpty)
                        Text(
                          item.availability!,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      if ((item.link ?? '').isNotEmpty)
                        TextButton(
                          onPressed: () => _launchShopLink(item.link!),
                          child: const Text('Produkt öffnen'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchShopLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class ImagePreview extends StatelessWidget {
  const ImagePreview({
    super.key,
    required this.bytes,
    required this.isWide,
    this.fileName,
  });

  final Uint8List bytes;
  final bool isWide;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.of(context).size.width;
                final ratio = isWide ? 16 / 9 : 4 / 3;
                final double targetHeight =
                    math.min(availableWidth / ratio, isWide ? 360 : 280);
                return SizedBox(
                  height: targetHeight,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 32),
                  ),
                );
              },
            ),
          ),
          if ((fileName ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                fileName!,
                style: const TextStyle(fontSize: 13, color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class PromptPreview extends StatelessWidget {
  final String prompt;
  const PromptPreview({super.key, required this.prompt});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0F172A),
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Generierter Prompt (für ChatGPT):',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                child: SelectableText(
                  prompt,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.white54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
