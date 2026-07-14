import 'package:flutter/material.dart';

import '../../models/study/study_enums.dart';
import '../../models/study/study_models.dart';
import '../../services/firebase_ready.dart';
import '../../services/study/study_dashboard_service.dart';
import '../../services/study/study_repository.dart';
import '../../widgets/ops_ui.dart';
import '../../widgets/page_hero.dart';
import '../../widgets/sidebar_navigation.dart';
import '../../widgets/study/study_widgets.dart';
import 'study_course_detail_screen.dart';

class StudyDashboardScreen extends StatelessWidget {
  const StudyDashboardScreen({super.key, this.onNavigate});

  final ValueChanged<ControlDestination>? onNavigate;

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePanel(
          title: '소통스터디부',
          message: 'Firebase 연결 후 학습 관제를 사용할 수 있습니다.',
        ),
      );
    }

    final repo = StudyRepository();
    final dash = StudyDashboardService();

    return StreamBuilder<List<StudyCourse>>(
      stream: repo.watchCourses(),
      builder: (context, courseSnap) {
        return StreamBuilder<List<StudySession>>(
          stream: repo.watchSessions(),
          builder: (context, sessionSnap) {
            return StreamBuilder<List<StudyProgress>>(
              stream: repo.watchProgress(),
              builder: (context, progressSnap) {
                return StreamBuilder<List<StudyAssignment>>(
                  stream: repo.watchAssignments(),
                  builder: (context, assignSnap) {
                    return StreamBuilder<List<StudyReviewItem>>(
                      stream: repo.watchReviews(),
                      builder: (context, reviewSnap) {
                        return StreamBuilder<List<StudyQuizAttempt>>(
                          stream: repo.watchAttempts(),
                          builder: (context, attemptSnap) {
                            return StreamBuilder<List<StudyGoal>>(
                              stream: repo.watchGoals(),
                              builder: (context, goalSnap) {
                                if (courseSnap.hasError) {
                                  return Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: EmptyStatePanel(
                                      title: '데이터 로딩 오류',
                                      message: '${courseSnap.error}',
                                    ),
                                  );
                                }

                                final courses = courseSnap.data ?? const [];
                                final sessions = sessionSnap.data ?? const [];
                                final progress = progressSnap.data ?? const [];
                                final assignments = assignSnap.data ?? const [];
                                final reviews = reviewSnap.data ?? const [];
                                final attempts = attemptSnap.data ?? const [];
                                final goals = goalSnap.data ?? const [];

                                // 챕터는 코스별로 필요 — 전체 합산을 위해 FutureBuilder
                                return FutureBuilder<List<StudyChapter>>(
                                  future: _allChapters(repo, courses),
                                  builder: (context, chSnap) {
                                    final chapters =
                                        chSnap.data ?? const <StudyChapter>[];
                                    final kpis = dash.compute(
                                      courses: courses,
                                      allChapters: chapters,
                                      progress: progress,
                                      sessions: sessions,
                                      assignments: assignments,
                                      reviews: reviews,
                                      attempts: attempts,
                                    );

                                    final inProgressCourses = courses
                                        .where(
                                          (c) =>
                                              c.status ==
                                                  StudyCourseStatus
                                                      .inProgress ||
                                              c.status ==
                                                  StudyCourseStatus.ready,
                                        )
                                        .toList();

                                    final today = DateTime.now();
                                    final todayStart = DateTime(
                                      today.year,
                                      today.month,
                                      today.day,
                                    );
                                    final todayGoals = goals
                                        .where(
                                          (g) =>
                                              !g.isDone &&
                                              g.targetDate != null &&
                                              g.targetDate!.year ==
                                                  todayStart.year &&
                                              g.targetDate!.month ==
                                                  todayStart.month &&
                                              g.targetDate!.day ==
                                                  todayStart.day,
                                        )
                                        .toList();
                                    final openAssign = assignments
                                        .where(
                                          (a) =>
                                              a.status !=
                                                  StudyAssignmentStatus
                                                      .completed &&
                                              a.status !=
                                                  StudyAssignmentStatus.onHold,
                                        )
                                        .take(5)
                                        .toList();
                                    final pendingReviews = reviews
                                        .where(
                                          (r) => r.reviewStatus == 'pending',
                                        )
                                        .take(5)
                                        .toList();

                                    return SingleChildScrollView(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          PageHero(
                                            title: '학습 대시보드',
                                            subtitle:
                                                '실제 학습 기록만 집계합니다. '
                                                '관심 분야 강의는 스터디 관리에서 직접 생성하십시오.',
                                            badge: '소통스터디부',
                                          ),
                                          const SizedBox(height: 16),
                                          if (courses.isEmpty)
                                            EmptyStatePanel(
                                              title: '아직 등록된 강의방이 없습니다',
                                              message:
                                                  '스터디 관리에서 첫 강의방을 생성하십시오.',
                                              actionLabel: '스터디 관리로 이동',
                                              onAction: onNavigate == null
                                                  ? null
                                                  : () => onNavigate!(
                                                      ControlDestination
                                                          .studyAdmin,
                                                    ),
                                            )
                                          else ...[
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 12,
                                              children: [
                                                KpiCard(
                                                  label: '전체 강의방',
                                                  value: '${kpis.courseCount}',
                                                ),
                                                KpiCard(
                                                  label: '수강 중',
                                                  value:
                                                      '${kpis.inProgressCourses}',
                                                ),
                                                KpiCard(
                                                  label: '완료 강의',
                                                  value:
                                                      '${kpis.completedCourses}',
                                                ),
                                                KpiCard(
                                                  label: '전체 챕터',
                                                  value:
                                                      '${kpis.totalChapters}',
                                                ),
                                                KpiCard(
                                                  label: '완료 챕터',
                                                  value:
                                                      '${kpis.completedChapters}',
                                                ),
                                                KpiCard(
                                                  label: '평균 진도율',
                                                  value:
                                                      kpis.averageProgress ==
                                                          null
                                                      ? '미설정'
                                                      : '${kpis.averageProgress}%',
                                                ),
                                                KpiCard(
                                                  label: '복습 필요',
                                                  value: '${kpis.reviewNeeded}',
                                                ),
                                                KpiCard(
                                                  label: '미완료 실습',
                                                  value:
                                                      '${kpis.openAssignments}',
                                                ),
                                                KpiCard(
                                                  label: '최근 7일 학습',
                                                  value:
                                                      '${kpis.sessionsLast7Days}회',
                                                ),
                                                KpiCard(
                                                  label: '이번 주 학습시간',
                                                  value:
                                                      kpis.studyMinutesThisWeek ==
                                                          0
                                                      ? '학습 기록 없음'
                                                      : '${kpis.studyMinutesThisWeek}분',
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 20),
                                            Text(
                                              '현재 수강 중인 강의',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 8),
                                            if (inProgressCourses.isEmpty)
                                              const Text('수강 중 강의가 없습니다.')
                                            else
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 12,
                                                children: inProgressCourses
                                                    .take(8)
                                                    .map(
                                                      (c) => SizedBox(
                                                        width: 320,
                                                        child: StudyCourseCard(
                                                          course: c,
                                                          compact: true,
                                                          onOpen: () =>
                                                              _openCourse(
                                                                context,
                                                                c.id,
                                                              ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            const SizedBox(height: 20),
                                            _panel(
                                              context,
                                              '오늘의 학습',
                                              todayGoals.isEmpty &&
                                                      openAssign.isEmpty
                                                  ? [
                                                      '오늘 등록된 학습 계획이 없습니다.',
                                                      '강의방에서 다음 학습 내용을 지정하십시오.',
                                                    ]
                                                  : [
                                                      ...todayGoals.map(
                                                        (g) => '목표: ${g.title}',
                                                      ),
                                                      ...openAssign.map(
                                                        (a) =>
                                                            '실습: ${a.title} (${StudyAssignmentStatus.labelKo(a.status)})',
                                                      ),
                                                      ...courses
                                                          .where(
                                                            (c) => c
                                                                .nextAction
                                                                .isNotEmpty,
                                                          )
                                                          .take(3)
                                                          .map(
                                                            (c) =>
                                                                '${c.title}: ${c.nextAction}',
                                                          ),
                                                    ],
                                            ),
                                            const SizedBox(height: 12),
                                            _panel(
                                              context,
                                              '복습 필요',
                                              pendingReviews.isEmpty &&
                                                      progress
                                                          .where(
                                                            (p) =>
                                                                p.needsReview,
                                                          )
                                                          .isEmpty
                                                  ? [
                                                      '복습할 항목이 없습니다.',
                                                      '학습 후 이해도와 복습 필요 여부를 기록하십시오.',
                                                    ]
                                                  : [
                                                      ...pendingReviews.map(
                                                        (r) =>
                                                            '${r.reason.isEmpty ? '복습 항목' : r.reason} · ${r.courseId}',
                                                      ),
                                                      ...progress
                                                          .where(
                                                            (p) =>
                                                                p.needsReview,
                                                          )
                                                          .take(5)
                                                          .map(
                                                            (p) =>
                                                                '진도 복습: ${p.chapterId}',
                                                          ),
                                                    ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<StudyChapter>> _allChapters(
    StudyRepository repo,
    List<StudyCourse> courses,
  ) async {
    final all = <StudyChapter>[];
    for (final c in courses) {
      all.addAll(await repo.fetchChapters(c.id));
    }
    return all;
  }

  void _openCourse(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyCourseDetailScreen(courseId: id),
      ),
    );
  }

  Widget _panel(BuildContext context, String title, List<String> lines) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...lines.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $e'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
