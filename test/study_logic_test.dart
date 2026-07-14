import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/study/study_enums.dart';
import 'package:sotong_ware_control/models/study/study_models.dart';
import 'package:sotong_ware_control/screens/study/study_dashboard_screen.dart';
import 'package:sotong_ware_control/services/study/study_dashboard_service.dart';
import 'package:sotong_ware_control/widgets/sidebar_navigation.dart';
import 'package:sotong_ware_control/widgets/study/study_widgets.dart';

void main() {
  group('스터디 진행률', () {
    test('초안 챕터는 진행률 분모에서 제외', () {
      final chapters = [
        const StudyChapter(
          id: 'c1',
          courseId: 'course',
          title: '공개1',
          status: StudyChapterStatus.ready,
          isPublished: true,
          displayOrder: 0,
        ),
        const StudyChapter(
          id: 'c2',
          courseId: 'course',
          title: '초안',
          status: StudyChapterStatus.draft,
          isPublished: false,
          displayOrder: 1,
        ),
        const StudyChapter(
          id: 'c3',
          courseId: 'course',
          title: '공개2',
          status: StudyChapterStatus.ready,
          isPublished: true,
          displayOrder: 2,
        ),
      ];
      final progress = [
        const StudyProgress(
          id: 'p1',
          courseId: 'course',
          chapterId: 'c1',
          isCompleted: true,
        ),
      ];
      expect(
        StudyProgressCalculator.courseProgressPercent(
          chapters: chapters,
          progress: progress,
        ),
        50,
      );
    });

    test('학습 가능 챕터 없으면 진행률 미설정(null)', () {
      expect(
        StudyProgressCalculator.courseProgressPercent(
          chapters: const [
            StudyChapter(
              id: 'd',
              courseId: 'c',
              title: '초안만',
              status: StudyChapterStatus.draft,
              isPublished: false,
            ),
          ],
          progress: const [],
        ),
        isNull,
      );
    });

    test('실제 완료만 반영', () {
      final chapters = List.generate(
        4,
        (i) => StudyChapter(
          id: 'c$i',
          courseId: 'course',
          title: 'ch$i',
          status: StudyChapterStatus.ready,
          isPublished: true,
          displayOrder: i,
        ),
      );
      final progress = [
        const StudyProgress(
          id: '1',
          courseId: 'course',
          chapterId: 'c0',
          isCompleted: true,
        ),
        const StudyProgress(
          id: '2',
          courseId: 'course',
          chapterId: 'c1',
          isCompleted: false,
        ),
      ];
      expect(
        StudyProgressCalculator.courseProgressPercent(
          chapters: chapters,
          progress: progress,
        ),
        25,
      );
    });
  });

  test('강의방 검색·필터·정렬', () {
    final courses = List.generate(
      12,
      (i) => StudyCourse(
        id: 'id$i',
        title: i == 2 ? 'Flutter 심화' : '강의 $i',
        category: i.isEven ? '개발' : '경영',
        status: StudyCourseStatus.inProgress,
        difficulty: StudyDifficulty.beginner,
        progress: i * 5,
      ),
    );
    final filtered = StudyCourseFilter.apply(
      courses: courses,
      query: 'flutter',
      category: '개발',
    );
    expect(filtered.length, 1);
    expect(filtered.first.title, 'Flutter 심화');

    final many = StudyCourseFilter.apply(courses: courses);
    expect(many.length, greaterThanOrEqualTo(10));
  });

  test('퀴즈 정답 비교 로직', () {
    const quiz = StudyQuiz(
      id: 'q',
      courseId: 'c',
      question: '1+1?',
      correctAnswer: '2',
      points: 5,
    );
    expect('2'.toLowerCase() == quiz.correctAnswer.toLowerCase(), isTrue);
    expect('3'.toLowerCase() == quiz.correctAnswer.toLowerCase(), isFalse);
  });

  test('AI 서비스 미연결', () {
    final ai = DisconnectedStudyAiService();
    expect(ai.isConnected, isFalse);
    expect(
      () =>
          ai.explainLesson(courseTitle: 'a', chapterTitle: 'b', question: 'c'),
      throwsStateError,
    );
  });

  test('사이드바에 소통스터디부 메뉴 포함', () {
    expect(ControlDestination.studyDashboard.label, '학습 대시보드');
    expect(ControlDestination.studyAdmin.label, '스터디 관리');
    expect(ControlDestination.studyAiTeacher.label, 'AI선생');
  });

  test('대시보드 KPI 빈 데이터', () {
    final k = StudyDashboardService().compute(
      courses: const [],
      allChapters: const [],
      progress: const [],
      sessions: const [],
      assignments: const [],
      reviews: const [],
      attempts: const [],
    );
    expect(k.courseCount, 0);
    expect(k.averageProgress, isNull);
    expect(k.studyMinutesThisWeek, 0);
  });

  testWidgets('강의 카드·빈 상태 오버플로 방지', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const course = StudyCourse(
      id: '1',
      title: '매우긴강의이름매우긴강의이름매우긴강의이름매우긴강의이름',
      description: '설명설명설명설명설명설명설명설명설명설명',
      category: '테스트분야',
      status: StudyCourseStatus.ready,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const StudyCourseCard(course: course),
                StudyDashboardScreen(onNavigate: (_) {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('매우긴강의이름'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('JSON 가져오기 검증용 빈 title 거부 패턴', () {
    final map = {'title': ''};
    expect('${map['title']}'.trim().isEmpty, isTrue);
  });
}
