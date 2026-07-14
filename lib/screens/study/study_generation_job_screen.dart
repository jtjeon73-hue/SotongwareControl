import 'package:flutter/material.dart';

import '../../models/study/study_generation_enums.dart';
import '../../models/study/study_generation_models.dart';
import '../../services/firebase_ready.dart';
import '../../services/study/study_ai_providers.dart';
import '../../services/study/study_generation_service.dart';
import '../../theme/control_theme.dart';
import '../../widgets/ops_ui.dart';
import '../../widgets/page_hero.dart';
import 'study_course_detail_screen.dart';
import 'study_lesson_screen.dart';

class StudyGenerationJobScreen extends StatefulWidget {
  const StudyGenerationJobScreen({
    super.key,
    required this.jobId,
    required this.courseId,
  });

  final String jobId;
  final String courseId;

  @override
  State<StudyGenerationJobScreen> createState() =>
      _StudyGenerationJobScreenState();
}

class _StudyGenerationJobScreenState extends State<StudyGenerationJobScreen> {
  final _svc = StudyGenerationService();
  final _provider = DisconnectedStudyAiProvider();
  bool _busy = false;

  Future<void> _act(Future<void> Function() fn, String ok) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok)));
      }
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

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Scaffold(body: Center(child: Text('Firebase 미연결')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('강의 생성 상태'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      StudyCourseDetailScreen(courseId: widget.courseId),
                ),
              );
            },
            child: const Text('강의방'),
          ),
        ],
      ),
      body: StreamBuilder<StudyGenerationJob?>(
        stream: _svc.watchJob(widget.jobId),
        builder: (context, jobSnap) {
          final job = jobSnap.data;
          if (job == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<List<StudyLesson>>(
            stream: _svc.watchLessons(widget.courseId),
            builder: (context, lesSnap) {
              final lessons = lesSnap.data ?? const [];
              final passed = lessons
                  .where(
                    (l) => l.validationStatus == StudyValidationStatus.passed,
                  )
                  .length;
              final needs = lessons
                  .where(
                    (l) =>
                        l.validationStatus == StudyValidationStatus.needsReview,
                  )
                  .length;
              final failed = lessons
                  .where(
                    (l) => l.validationStatus == StudyValidationStatus.failed,
                  )
                  .length;
              final withBody = lessons.where((l) => l.hasBody).length;

              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const PageHero(
                    title: 'AI 강의 생성 진행',
                    subtitle: '페이지를 닫아도 Firestore에 상태가 유지됩니다.',
                    badge: '생성',
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: _provider.isConnected
                        ? null
                        : ControlColors.accentWarm.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _provider.isConnected
                            ? 'AI 연결됨'
                            : _provider.connectionMessage,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_busy) const LinearProgressIndicator(),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '관심 분야: ${job.interestField.isEmpty ? '—' : job.interestField}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('상태: ${StudyJobStatus.labelKo(job.status)}'),
                          Text('전체 예정 강의: ${job.requestedLessonCount}강'),
                          Text('목차(골격) 강의: ${lessons.length}강'),
                          Text('본문 생성 완료: $withBody강'),
                          Text('검증 통과: $passed강'),
                          Text('검토 필요: $needs강'),
                          Text('실패: $failed강'),
                          Text(
                            '진행률: ${job.progress == null ? '미설정' : '${job.progress}%'}',
                          ),
                          if (job.lastError.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              job.lastError,
                              style: TextStyle(color: ControlColors.accentWarm),
                            ),
                          ],
                          Text(
                            '비용: ${StudyAiUsageDisplay.costLabel(inputTokens: null, outputTokens: null)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _act(
                                () => _svc.approveJob(job.id),
                                '승인했습니다. (본문 AI 생성은 연결 후 가능)',
                              ),
                        child: const Text('목차 승인'),
                      ),
                      FilledButton.tonal(
                        onPressed: _busy
                            ? null
                            : () => _act(
                                () => _svc.startLessonBodyGeneration(job.id),
                                '본문 생성 요청을 처리했습니다.',
                              ),
                        child: const Text('본문 생성 시작'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _act(
                                () => _svc.pauseJob(job.id),
                                '일시정지했습니다.',
                              ),
                        child: const Text('일시정지'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _act(
                                () => _svc.resumeJob(job.id),
                                '재개(대기열)로 변경했습니다.',
                              ),
                        child: const Text('재개'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () =>
                                  _act(() => _svc.cancelJob(job.id), '취소했습니다.'),
                        child: const Text('취소'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _act(() async {
                                await _svc.createEmptyOutlineScaffold(
                                  courseId: widget.courseId,
                                  jobId: job.id,
                                  interestField: job.interestField,
                                  lessonCount: job.requestedLessonCount,
                                  versionId: job.courseVersionId,
                                );
                              }, '빈 목차 골격을 생성했습니다.'),
                        child: const Text('빈 목차 골격 생성'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '개별 강의 목록 (${lessons.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (lessons.isEmpty)
                    const EmptyStatePanel(
                      title: '아직 목차가 없습니다',
                      message:
                          'AI 미연결 상태에서는 「빈 목차 골격 생성」으로 30강 이상 구조를 만들 수 있습니다.',
                    )
                  else
                    ...lessons.map(
                      (l) => Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          title: Text(
                            '${l.lessonNumber}. ${l.title}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${StudyLessonType.labelKo(l.lessonType)} · '
                            '${StudyValidationStatus.labelKo(l.validationStatus)} · '
                            '${l.isPublished ? '공개' : '비공개'}'
                            '${l.hasBody ? ' · 본문있음' : ' · 본문없음'}',
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => StudyLessonScreen(
                                  courseId: widget.courseId,
                                  lessonId: l.id,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
