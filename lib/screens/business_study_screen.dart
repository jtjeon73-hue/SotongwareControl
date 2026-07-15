import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/business/business_study_content.dart';
import '../theme/control_theme.dart';
import '../widgets/page_hero.dart';

class BusinessStudyScreen extends StatefulWidget {
  const BusinessStudyScreen({super.key});

  @override
  State<BusinessStudyScreen> createState() => _BusinessStudyScreenState();
}

class _BusinessStudyScreenState extends State<BusinessStudyScreen> {
  static const _completedKey = 'business_study_completed_v1';
  var _domainIndex = 0;
  var _lessonIndex = 0;
  Set<String> _completed = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _completed = preferences.getStringList(_completedKey)?.toSet() ?? {};
    });
  }

  Future<void> _toggleComplete(String id) async {
    final next = {..._completed};
    if (!next.add(id)) next.remove(id);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_completedKey, next.toList());
    if (mounted) setState(() => _completed = next);
  }

  @override
  Widget build(BuildContext context) {
    final domain = BusinessStudyContent.domains[_domainIndex];
    final lesson =
        domain.lessons[_lessonIndex.clamp(0, domain.lessons.length - 1)];
    final allLessons = BusinessStudyContent.domains
        .expand((item) => item.lessons)
        .length;
    final progress = allLessons == 0 ? 0.0 : _completed.length / allLessons;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHero(
            title: '소통사업스터디부',
            subtitle:
                '소통웨어의 실제 5개 사업에 적용할 사업가 마인드·필수 지식·전략·소프트웨어·AI 흐름을 학습합니다.',
            badge: '사업 성장 학습',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('학습 진행 ${_completed.length}/$allLessons'),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 6),
                  const Text(
                    '이 기본 콘텐츠의 완료 상태는 현재 브라우저에 저장됩니다. '
                    '기존 Firestore 강의방·노트·퀴즈 데이터는 삭제하지 않고 관리 화면에서 계속 사용할 수 있습니다.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: [
                for (var i = 0; i < BusinessStudyContent.domains.length; i++)
                  ButtonSegment<int>(
                    value: i,
                    label: Text(BusinessStudyContent.domains[i].title),
                  ),
              ],
              selected: {_domainIndex},
              onSelectionChanged: (selection) {
                setState(() {
                  _domainIndex = selection.first;
                  _lessonIndex = 0;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            domain.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < domain.lessons.length; i++)
                ChoiceChip(
                  selected: i == _lessonIndex,
                  avatar: _completed.contains(domain.lessons[i].id)
                      ? const Icon(Icons.check_circle, size: 16)
                      : null,
                  label: Text(domain.lessons[i].title),
                  onSelected: (_) => setState(() => _lessonIndex = i),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  _Section(title: '오늘의 핵심 지식', body: lesson.coreConcept),
                  _Section(title: '자세한 설명', body: lesson.detail),
                  _Section(title: '실제 사업 사례', body: lesson.caseStudy),
                  _Section(
                    title: '소통웨어에 적용하기',
                    body: lesson.sotongApplication,
                    emphasized: true,
                  ),
                  _Section(title: '생각해볼 질문', body: lesson.question),
                  _Section(title: '실행 과제', body: lesson.action),
                  _Section(title: '핵심 요약', body: lesson.summary),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('학습 완료 체크'),
                    subtitle: const Text('내용을 읽고 실행 과제를 확인한 뒤 직접 완료합니다.'),
                    value: _completed.contains(lesson.id),
                    onChanged: (_) => _toggleComplete(lesson.id),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.body,
    this.emphasized = false,
  });

  final String title;
  final String body;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: emphasized ? const EdgeInsets.all(14) : EdgeInsets.zero,
      decoration: emphasized
          ? BoxDecoration(
              color: ControlColors.tealSoft,
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          SelectableText(body),
        ],
      ),
    );
  }
}
