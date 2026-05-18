import 'package:flutter/material.dart';
import '../models/bf_batch.dart';
import 'batch_detail_tabs/planning_tab.dart';
import 'batch_detail_tabs/brewing_tab.dart';
import 'batch_detail_tabs/fermenting_tab.dart';
import 'batch_detail_tabs/completed_tab.dart';
import 'batch_detail_tabs/analysis_tab.dart';
import 'batch_detail_tabs/json_tabs.dart';

class BatchDetailPage extends StatefulWidget {
  const BatchDetailPage({super.key, required this.batch});

  final BfBatch batch;

  @override
  State<BatchDetailPage> createState() => _BatchDetailPageState();
}

class _BatchDetailPageState extends State<BatchDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.batch.name),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF66B342),
          labelColor: const Color(0xFF66B342),
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          tabs: const [
            Tab(text: 'IN PLANUNG'),
            Tab(text: 'BRAUEN'),
            Tab(text: 'IN GÄRUNG'),
            Tab(text: 'ABGESCHLOSSEN'),
            Tab(text: 'ANALYSE'),
            Tab(text: 'JSON'),
            Tab(text: 'JSON ROH'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          PlanningTab(batch: widget.batch),
          BrewingTab(batch: widget.batch),
          FermentingTab(batch: widget.batch),
          CompletedTab(batch: widget.batch),
          AnalysisTab(batch: widget.batch),
          JsonTab(batch: widget.batch),
          RawJsonTab(batch: widget.batch),
        ],
      ),
    );
  }
}
