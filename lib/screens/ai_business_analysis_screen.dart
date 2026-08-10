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
            subtitle: '아이디어를 선택하면 AI 설계 엔진이 고객·주제·제작·검토까지 도와 최고의 작업지시서를 만듭니다.',
            badge: 'Project Design Engine',
            compact: true,
          ),
          const SizedBox(height: 8),
          BusinessPlanningTab(ideaSeed: ideaSeed),
        ],
      ),
    );
  }
}
