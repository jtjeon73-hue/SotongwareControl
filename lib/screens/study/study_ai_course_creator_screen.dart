import 'package:flutter/material.dart';

import '../../models/study/study_enums.dart';
import '../../models/study/study_generation_models.dart';
import '../../services/firebase_ready.dart';
import '../../services/study/study_ai_providers.dart';
import '../../services/study/study_generation_service.dart';
import '../../theme/control_theme.dart';
import '../../widgets/ops_ui.dart';
import '../../widgets/page_hero.dart';
import 'study_generation_job_screen.dart';

/// AI 강의 만들기 — 조건 저장 + (미연결 시) 빈 목차 골격
class StudyAiCourseCreatorScreen extends StatefulWidget {
  const StudyAiCourseCreatorScreen({super.key});

  @override
  State<StudyAiCourseCreatorScreen> createState() =>
      _StudyAiCourseCreatorScreenState();
}

class _StudyAiCourseCreatorScreenState extends State<StudyAiCourseCreatorScreen> {
  final _svc = StudyGenerationService();
  final _provider = DisconnectedStudyAiProvider();

  final _interest = TextEditingController();
  final _title = TextEditingController();
  final _goal = TextEditingController();
  final _currentLevel = TextEditingController();
  final _targetLevel = TextEditingController();
  final _lessonCount = TextEditingController(text: '35');
  final _period = TextEditingController();
  final _weekly = TextEditingController();
  final _ratio = TextEditingController(text: '40/60');
  final _include = TextEditingController();
  final _exclude = TextEditingController();
  final _deliverable = TextEditingController();
  final _bu = TextEditingController();
  final _project = TextEditingController();
  final _refs = TextEditingController();
  final _memo = TextEditingController();
  var _difficulty = StudyDifficulty.beginner;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _interest,
      _title,
      _goal,
      _currentLevel,
      _targetLevel,
      _lessonCount,
      _period,
      _weekly,
      _ratio,
      _include,
      _exclude,
      _deliverable,
      _bu,
      _project,
      _refs,
      _memo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  StudyCourseGenerationRequest _buildRequest() {
    final n = int.tryParse(_lessonCount.text.trim()) ?? 30;
    return StudyCourseGenerationRequest(
      interestField: _interest.text.trim(),
      courseTitle: _title.text.trim(),
      learningGoal: _goal.text.trim(),
      currentLevel: _currentLevel.text.trim(),
      targetLevel: _targetLevel.text.trim(),
      difficulty: _difficulty,
      requestedLessonCount: n < 30 ? 30 : n,
      studyPeriod: _period.text.trim(),
      weeklyHours: _weekly.text.trim(),
      theoryPracticeRatio: _ratio.text.trim(),
      includeTopics: _include.text.trim(),
      excludeTopics: _exclude.text.trim(),
      finalDeliverable: _deliverable.text.trim(),
      relatedBusinessUnitId: _bu.text.trim(),
      relatedProjectId: _project.text.trim(),
      references: _refs.text.trim(),
      memo: _memo.text.trim(),
    );
  }

  Future<void> _saveRequest({bool alsoScaffold = false}) async {
    if (_interest.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관심 분야를 입력하십시오.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final req = _buildRequest();
      final jobId = await _svc.createGenerationRequest(request: req);
      String? versionId;
      final jobSnap = await _svc.watchJob(jobId).first;
      final courseId = jobSnap?.courseId ?? '';

      if (alsoScaffold && courseId.isNotEmpty) {
        versionId = await _svc.createEmptyOutlineScaffold(
          courseId: courseId,
          jobId: jobId,
          interestField: req.interestField,
          lessonCount: req.requestedLessonCount,
          difficulty: req.difficulty,
          versionId: jobSnap?.courseVersionId,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alsoScaffold
                ? '생성 조건을 저장하고 빈 목차 골격(${req.requestedLessonCount}강)을 만들었습니다. (AI 본문 아님)'
                : '생성 조건을 저장했습니다. AI는 아직 연결되지 않았습니다.',
          ),
        ),
      );
      if (courseId.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => StudyGenerationJobScreen(
              jobId: jobId,
              courseId: courseId,
            ),
          ),
        );
      }
      // silence unused
      versionId;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류: $e'),
            backgroundColor: ControlColors.accentWarm,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _tryAiOutline() async {
    setState(() => _busy = true);
    try {
      await _svc.requestAiOutline(_buildRequest());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: ControlColors.accentWarm,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePanel(
          title: 'AI 강의 만들기',
          message: 'Firebase 연결 후 이용할 수 있습니다.',
        ),
      );
    }

    final connected = _provider.isConnected;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHero(
            title: 'AI 강의 만들기',
            subtitle:
                '관심 분야와 학습 조건을 입력합니다. '
                'AI가 연결되면 30강 이상 목차를 설계하고, 승인 후 본문을 순차 생성합니다.',
            badge: '생성',
          ),
          const SizedBox(height: 12),
          Card(
            color: connected
                ? ControlColors.surface
                : ControlColors.accentWarm.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    connected ? Icons.check_circle_outline : Icons.info_outline,
                    color: connected
                        ? ControlColors.teal
                        : ControlColors.accentWarm,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      connected
                          ? 'AI 공급자가 연결되어 있습니다.'
                          : _provider.connectionMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _interest,
                    decoration: const InputDecoration(
                      labelText: '관심 분야 *',
                      hintText: '예: Flutter 앱개발',
                    ),
                  ),
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: '강의명'),
                  ),
                  TextField(
                    controller: _goal,
                    decoration: const InputDecoration(labelText: '배우려는 목적'),
                    maxLines: 2,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _currentLevel,
                          decoration: const InputDecoration(
                            labelText: '현재 지식 수준',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _targetLevel,
                          decoration: const InputDecoration(labelText: '목표 수준'),
                        ),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _difficulty,
                    decoration: const InputDecoration(labelText: '선호 난이도'),
                    items: [
                      StudyDifficulty.beginner,
                      StudyDifficulty.intermediate,
                      StudyDifficulty.advanced,
                    ]
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(StudyDifficulty.labelKo(e)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _difficulty = v ?? _difficulty),
                  ),
                  TextField(
                    controller: _lessonCount,
                    decoration: const InputDecoration(
                      labelText: '예상 전체 강의 수 (최소 30)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: _period,
                    decoration: const InputDecoration(labelText: '학습 기간'),
                  ),
                  TextField(
                    controller: _weekly,
                    decoration: const InputDecoration(
                      labelText: '하루 또는 주간 학습 시간',
                    ),
                  ),
                  TextField(
                    controller: _ratio,
                    decoration: const InputDecoration(
                      labelText: '이론과 실습 비율',
                      hintText: '40/60',
                    ),
                  ),
                  TextField(
                    controller: _include,
                    decoration: const InputDecoration(
                      labelText: '포함하고 싶은 내용',
                    ),
                    maxLines: 2,
                  ),
                  TextField(
                    controller: _exclude,
                    decoration: const InputDecoration(
                      labelText: '제외하고 싶은 내용',
                    ),
                    maxLines: 2,
                  ),
                  TextField(
                    controller: _deliverable,
                    decoration: const InputDecoration(labelText: '최종 결과물'),
                  ),
                  TextField(
                    controller: _bu,
                    decoration: const InputDecoration(labelText: '관련 사업부 ID'),
                  ),
                  TextField(
                    controller: _project,
                    decoration: const InputDecoration(
                      labelText: '관련 프로젝트 ID',
                    ),
                  ),
                  TextField(
                    controller: _refs,
                    decoration: const InputDecoration(
                      labelText: '참고 자료 (줄바꿈 구분)',
                    ),
                    maxLines: 2,
                  ),
                  TextField(
                    controller: _memo,
                    decoration: const InputDecoration(labelText: '메모'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: _busy ? null : () => _saveRequest(alsoScaffold: false),
                child: const Text('생성 조건 저장'),
              ),
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _saveRequest(alsoScaffold: true),
                child: const Text('저장 + 빈 목차 골격(≥30강)'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _tryAiOutline,
                child: const Text('AI 목차 생성 요청'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '빈 목차 골격은 제목 플레이스홀더만 만들며, 가짜 본문·완료 강의를 넣지 않습니다. '
            '비용: ${StudyAiUsageDisplay.costLabel(inputTokens: null, outputTokens: null)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
