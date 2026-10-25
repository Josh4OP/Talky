import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/analysis.dart';
import '../models/analysis_summary.dart';
import '../screens/new_analysis_screen.dart';
import '../screens/result_screen.dart';

Future<void> openNewAnalysis(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const NewAnalysisScreen()),
  );
}

Future<void> openResult(
  BuildContext context, {
  Analysis? analysis,
  AnalysisSummary? summary,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ResultScreen(analysis: analysis, summary: summary),
    ),
  );
}

Future<void> openDemoResult(BuildContext context, [AnalysisSummary? summary]) {
  return openResult(
    context,
    analysis: DemoData.analysis(summary: summary),
  );
}
