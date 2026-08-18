import 'package:flutter/material.dart';

import '../models/idea_bank.dart';
import '../widgets/page_hero.dart';
import 'business_planning_tab.dart';

/// 작업지시 제작소 — Project Design Engine 전용 화면.
class AiBusinessAnalysisScreen extends StatelessWidget {
  const AiBusinessAnalysisScreen({super.key, this.ideaSeed});

  final IdeaToPlanningSeed? ideaSeed;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHero(
            title: '작업지시 제작소',
            subtitle: '새 작업을 만들고 Sotong24Work로 보내는 곳입니다.',
            badge: '새 작업',
            compact: true,
          ),
          const SizedBox(height: 8),
          BusinessPlanningTab(ideaSeed: ideaSeed),
        ],
      ),
    );
  }
}
