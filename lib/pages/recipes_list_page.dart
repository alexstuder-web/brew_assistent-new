import 'package:flutter/material.dart';
import '../services/brewfather_service.dart';
import '../services/user_profile_service.dart';
import '../models/bf_recipe.dart';
import 'recipe_detail_page.dart';

class RecipesListPage extends StatefulWidget {
  const RecipesListPage({super.key, required this.profileId});

  final String profileId;

  @override
  State<RecipesListPage> createState() => _RecipesListPageState();
}

class _RecipesListPageState extends State<RecipesListPage> {
  final UserProfileService _userService = UserProfileService();
  bool _isLoading = true;
  String? _error;
  List<BfRecipe> _recipes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await _userService.fetchProfile(widget.profileId);
      if (profile == null) throw Exception('Profil nicht gefunden');

      // 1. Load from DB
      var localItems = await _userService.getRecipes(widget.profileId);
      if (mounted && localItems.isNotEmpty) {
        setState(() {
          _recipes = localItems;
          _isLoading = false;
        });
      }

      if ((profile.brewfatherUserId ?? '').isEmpty ||
          (profile.brewfatherApiKey ?? '').isEmpty) {
        if (localItems.isEmpty) {
           throw Exception('Bitte hinterlegen Sie erst Ihre Brewfather User ID und API Key.');
        } else {
             if (mounted) setState(() => _isLoading = false);
             return;
        }
      }

      final bfService = BrewfatherService(
        userId: profile.brewfatherUserId!,
        apiKey: profile.brewfatherApiKey!,
      );

      // 2. Fetch
      final bfData = await bfService.getRecipes();

      // 3. Convert
      final List<BfRecipe> newItems = [];
      for (var item in bfData) {
        newItems.add(BfRecipe.fromBrewfather(item, widget.profileId));
      }

      // 4. Save
      await _userService.saveRecipes(newItems);

      // 5. Reload
      localItems = await _userService.getRecipes(widget.profileId);

      if (!mounted) return;

      setState(() {
        _recipes = localItems;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rezepte (Brewfather)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Fehler beim Laden: $_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    if (_recipes.isEmpty) {
      return const Center(
        child: Text('Keine Rezepte gefunden.'),
      );
    }

    return ListView.separated(
      itemCount: _recipes.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _recipes[index];
        final style = item.style ?? 'Unbekannter Stil';
        
        return ListTile(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecipeDetailPage(recipe: item),
              ),
            );
          },
          leading: Image.asset('assets/Brewfather_logo.png', width: 32, height: 32),
          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            '$style • ${item.abv?.toStringAsFixed(1)}% ABV • ${item.ibu?.toStringAsFixed(0)} IBU',
            style: const TextStyle(color: Colors.white70),
          ),
          trailing: const Icon(Icons.chevron_right),
        );
      },
    );
  }
}
