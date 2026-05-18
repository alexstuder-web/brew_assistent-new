import 'package:flutter/material.dart';
import '../services/brewfather_service.dart';
import '../services/user_profile_service.dart';
import '../models/bf_batch.dart';
import 'batch_detail_page.dart';

class BatchesListPage extends StatefulWidget {
  const BatchesListPage({super.key, required this.profileId});

  final String profileId;

  @override
  State<BatchesListPage> createState() => _BatchesListPageState();
}

class _BatchesListPageState extends State<BatchesListPage> {
  final UserProfileService _userService = UserProfileService();
  bool _isLoading = true;
  String? _error;
  List<BfBatch> _batches = [];

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
      var localItems = await _userService.getBatches(widget.profileId);
      if (mounted && localItems.isNotEmpty) {
        setState(() {
          _batches = localItems;
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
      final bfData = await bfService.getBatches();

      // 3. Convert
      final List<BfBatch> newItems = [];
      for (var item in bfData) {
        newItems.add(BfBatch.fromBrewfather(item, widget.profileId));
      }

      // 4. Save (with syncDeletions: true to remove local entries no longer in Brewfather)
      await _userService.saveBatches(newItems, syncDeletions: true);

      // 5. Reload
      localItems = await _userService.getBatches(widget.profileId);

      if (!mounted) return;

      setState(() {
        _batches = localItems;
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
        title: const Text('Sud (Brewfather)'),
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

    if (_batches.isEmpty) {
      return const Center(
        child: Text('Keine Sude gefunden.'),
      );
    }

    // Sort by Brew Date descending
    final displayedBatches = List<BfBatch>.from(_batches);
    displayedBatches.sort((a, b) => (b.brewDate ?? 0).compareTo(a.brewDate ?? 0));

    return ListView.separated(
      itemCount: displayedBatches.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = displayedBatches[index];
        final status = item.status ?? '';
        final date = item.brewDate != null 
            ? DateTime.fromMillisecondsSinceEpoch(item.brewDate!).toString().split(' ')[0] 
            : '-';

        return ListTile(
          onTap: () {
             Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BatchDetailPage(batch: item),
              ),
            );
          },
          leading: CircleAvatar(
            backgroundColor: Colors.blueGrey,
            child: Text('#${item.batchNo ?? '?'}', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            '$status • Gebraut: $date',
            style: const TextStyle(color: Colors.white70),
          ),
          trailing: const Icon(Icons.chevron_right),
        );
      },
    );
  }
}
