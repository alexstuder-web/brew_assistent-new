import '../models/bf_batch.dart';

/// Placeholder for fermenting-tab state for a single batch.
/// RAPT telemetry removed (Phase 5 pivot — RAPT is rapt_dashboard's domain).
/// No live notifications needed; kept as a plain object for future extension.
class FermentingController {
  FermentingController(this.batch);

  final BfBatch batch;
}
