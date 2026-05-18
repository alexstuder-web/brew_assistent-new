import 'package:flutter/material.dart';
import '../controllers/recipe_prompt_controller.dart';
import 'recipe_result_page.dart';
import 'user_profile_page.dart';
import '../widgets/user_name_banner.dart';
import '../widgets/recipe_prompt_widgets.dart';

class RecipePromptPage extends StatefulWidget {
  const RecipePromptPage({super.key});

  static const String routeName = '/prompt';

  @override
  State<RecipePromptPage> createState() => _RecipePromptPageState();
}

class _RecipePromptPageState extends State<RecipePromptPage> {
  late final RecipePromptController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RecipePromptController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchShops() async {
    try {
      final results = await _controller.searchShopsForIngredients();
      if (!mounted) return;
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Zutaten für die Shopsuche gefunden.')),
        );
        return;
      }
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ShopResultsSheet(results: results),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shopsuche fehlgeschlagen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AiBrewGenius'),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, child) {
          return Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: UserNameBanner(),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Image.asset(
                            'assets/icon_small.png',
                            height: 98,
                            filterQuality: FilterQuality.none,
                            semanticLabel: 'AiBrewGenius',
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Wähle dein Equipment und Abfüll Profil',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              OutlinedButton(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const UserProfilePage()),
                                  );
                                },
                                child: const Text('Zum Profil'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controller.promptController,
                          maxLines: 5,
                          minLines: 3,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Beschreibe deinen Wunsch-Sud (Stil, Aromen, ABV …)',
                            errorText: _controller.error,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: _controller.isLoading
                                  ? null
                                  : () => _controller.requestRecipe(context, () {
                                        if (mounted && _controller.lastGeneratedRecipe != null) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => RecipeResultPage(recipe: _controller.lastGeneratedRecipe!),
                                            ),
                                          );
                                        }
                                      }),
                              icon: _controller.isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.auto_awesome),
                              label: Text(_controller.isLoading ? 'Zaubere Rezept …' : 'Rezept generieren'),
                              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24)),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _controller.isLoading ? null : () => _controller.pickImage((msg) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                              }),
                              tooltip: 'Bild hochladen (z.B. Etikett, Bierglas...)',
                              icon: const Icon(Icons.image),
                            ),
                            if (_controller.imageBytes != null)
                              IconButton(
                                onPressed: _controller.isLoading ? null : _controller.clearImage,
                                icon: const Icon(Icons.close, color: Colors.redAccent),
                                tooltip: 'Bild entfernen',
                              ),
                          ],
                        ),
                        if (_controller.imageBytes != null) ...[
                          const SizedBox(height: 12),
                          ImagePreview(
                            bytes: _controller.imageBytes!,
                            isWide: MediaQuery.of(context).size.width >= 720,
                            fileName: _controller.imageName,
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (_controller.lastGeneratedRecipe != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => RecipeResultPage(recipe: _controller.lastGeneratedRecipe!)),
                                );
                              },
                              icon: const Icon(Icons.receipt_long),
                              label: const Text('Letztes Rezept anzeigen'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.amberAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
                            ),
                          ),
                        
                        if (_controller.lastGeneratedPrompt != null)
                          PromptPreview(prompt: _controller.lastGeneratedPrompt!),

                        if (_controller.responseText != null) ...[
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          Text('Ergebnis (JSON):', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(_controller.responseText!, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _controller.isLoading || _controller.isSearchingShops ? null : _onSearchShops,
                            icon: _controller.isSearchingShops
                                 ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                 : const Icon(Icons.shopping_cart),
                            label: Text(_controller.isSearchingShops ? 'Suche...' : 'Zutaten im Shop suchen'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }
}
