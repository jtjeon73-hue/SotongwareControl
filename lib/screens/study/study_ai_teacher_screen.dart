import 'package:flutter/material.dart';

import '../../models/study/study_enums.dart';
import '../../models/study/study_models.dart';
import '../../services/firebase_ready.dart';
import '../../services/study/study_dashboard_service.dart';
import '../../services/study/study_repository.dart';
import '../../theme/control_theme.dart';
import '../../widgets/ops_ui.dart';
import '../../widgets/page_hero.dart';

class StudyAiTeacherScreen extends StatefulWidget {
  const StudyAiTeacherScreen({super.key});

  @override
  State<StudyAiTeacherScreen> createState() => _StudyAiTeacherScreenState();
}

class _StudyAiTeacherScreenState extends State<StudyAiTeacherScreen> {
  final _repo = StudyRepository();
  final _ai = DisconnectedStudyAiService();
  final _question = TextEditingController();
  final _memo = TextEditingController();
  String? _courseId;
  String? _chapterId;

  @override
  void dispose() {
    _question.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _saveQuestion() async {
    if (_courseId == null || _question.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('강의와 질문을 입력하십시오.')),
      );
      return;
    }
    await _repo.upsertQuestion(
      StudyQuestion(
        id: '',
        courseId: _courseId!,
        chapterId: _chapterId ?? '',
        question: _question.text.trim(),
        personalMemo: _memo.text.trim(),
        status: StudyQuestionStatus.open,
        aiAnswer: '',
        answerSource: '',
      ),
      isNew: true,
    );
    _question.clear();
    _memo.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('질문을 저장했습니다. AI 자동 답변은 미연결입니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePanel(
          title: 'AI선생',
          message: 'Firebase 연결 후 사용할 수 있습니다.',
        ),
      );
    }

    return StreamBuilder<List<StudyCourse>>(
      stream: _repo.watchCourses(),
      builder: (context, courseSnap) {
        final courses = (courseSnap.data ?? const [])
            .where((c) => c.status != StudyCourseStatus.archived)
            .toList();
        return StreamBuilder<List<StudyQuestion>>(
          stream: _repo.watchQuestions(courseId: _courseId),
          builder: (context, qSnap) {
            final questions = qSnap.data ?? const [];
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageHero(
                    title: 'AI선생',
                    subtitle: '현재 강의·챕터 기준으로 질문을 저장합니다.',
                    badge: '소통스터디부',
                  ),
                  const SizedBox(height: 12),
                  const StatusBadge(
                    label: 'AI선생 미연결',
                    color: ControlColors.accentWarm,
                  ),
                  const SizedBox(height: 12),
                  const EmptyStatePanel(
                    title: 'AI선생 자동 대화 기능은 아직 연결되지 않았습니다',
                    message:
                        '현재는 질문과 학습 메모를 저장할 수 있습니다.\n'
                        '가짜 AI 답변은 표시하지 않습니다.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: _courseId,
                    decoration: const InputDecoration(labelText: '강의 선택'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('강의 선택'),
                      ),
                      ...courses.map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.title),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      _courseId = v;
                      _chapterId = null;
                    }),
                  ),
                  if (_courseId != null)
                    StreamBuilder<List<StudyChapter>>(
                      stream: _repo.watchChapters(_courseId!),
                      builder: (context, chSnap) {
                        final chapters = chSnap.data ?? const [];
                        return DropdownButtonFormField<String?>(
                          initialValue: _chapterId,
                          decoration: const InputDecoration(
                            labelText: '챕터 선택',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('챕터 선택(선택)'),
                            ),
                            ...chapters.map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.title),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _chapterId = v),
                        );
                      },
                    ),
                  TextField(
                    controller: _question,
                    decoration: const InputDecoration(labelText: '질문'),
                    maxLines: 3,
                  ),
                  TextField(
                    controller: _memo,
                    decoration: const InputDecoration(labelText: '개인 메모'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _saveQuestion,
                        child: const Text('질문 저장'),
                      ),
                      FilledButton.tonal(
                        onPressed: () {
                          try {
                            _ai.explainLesson(
                              courseTitle: '',
                              chapterTitle: '',
                              question: '',
                            );
                          } catch (_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'AI선생 자동 대화 기능은 아직 연결되지 않았습니다.',
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('쉬운 설명 요청(미연결)'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '저장된 질문',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (questions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('저장된 질문이 없습니다.'),
                    )
                  else
                    ...questions.map(
                      (q) => Card(
                        child: ListTile(
                          title: Text(q.question),
                          subtitle: Text(
                            '${StudyQuestionStatus.labelKo(q.status)}'
                            '${q.personalMemo.isEmpty ? '' : ' · ${q.personalMemo}'}'
                            '${q.aiAnswer.isEmpty ? ' · AI 답변 없음' : ''}',
                          ),
                          trailing: q.isImportant
                              ? const Icon(Icons.flag, color: ControlColors.accentWarm)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
