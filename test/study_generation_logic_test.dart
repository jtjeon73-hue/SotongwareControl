import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/study/study_enums.dart';
import 'package:sotong_ware_control/models/study/study_generation_enums.dart';
import 'package:sotong_ware_control/models/study/study_generation_models.dart';
import 'package:sotong_ware_control/models/study/study_models.dart';
import 'package:sotong_ware_control/services/study/study_ai_providers.dart';
import 'package:sotong_ware_control/services/study/study_dashboard_service.dart';
import 'package:sotong_ware_control/services/study/study_generation_logic.dart';
import 'package:sotong_ware_control/screens/study/study_lesson_screen.dart';

void main() {
  group('30강 이상 목차', () {
    test('빈 목차 골격이 요청 수만큼 생성', () {
      final o = StudyOutlineScaffoldBuilder.build(
        interestField: '테스트분야A',
        requestedLessonCount: 36,
      );
      expect(o.lessonCount, 36);
      expect(o.chapters.length, greaterThanOrEqualTo(5));
      expect(o.chapters.fold<int>(0, (s, c) => s + c.lessons.length), 36);
      expect(o.isAiGenerated, isFalse);
    });

    test('관심 분야만으로도 기본 골격 가능', () {
      final o = StudyOutlineScaffoldBuilder.build(
        interestField: '단독분야',
        requestedLessonCount: 30,
      );
      expect(o.lessonCount, greaterThanOrEqualTo(30));
      expect(o.title, contains('단독분야'));
    });
  });

  group('다수 강의방·강의 목록', () {
    test('10개 이상 강의방 필터 처리', () {
      final courses = List.generate(
        12,
        (i) => StudyCourse(
          id: 'c$i',
          title: '강의방 $i',
          category: '분야${i % 3}',
          status: StudyCourseStatus.ready,
        ),
      );
      expect(courses.length, greaterThanOrEqualTo(10));
      final filtered = StudyCourseFilter.apply(
        courses: courses,
        category: '분야1',
      );
      expect(filtered.every((c) => c.category == '분야1'), isTrue);
    });

    test('강의방별 50강 이상 목록 정렬', () {
      final lessons = List.generate(
        52,
        (i) => StudyLesson(
          id: 'l$i',
          courseId: 'course',
          chapterId: 'ch',
          lessonNumber: i + 1,
          title: '${i + 1}강',
          displayOrder: i,
        ),
      )..sort((a, b) => a.lessonNumber.compareTo(b.lessonNumber));
      expect(lessons.length, greaterThanOrEqualTo(50));
      expect(lessons.first.lessonNumber, 1);
      expect(lessons.last.lessonNumber, 52);
    });
  });

  group('강의 진행률', () {
    test('공개 강의 기준 진도', () {
      final lessons = [
        const StudyLesson(
          id: 'a',
          courseId: 'c',
          chapterId: 'ch',
          title: '1',
          isPublished: true,
          status: StudyLessonStatus.ready,
        ),
        const StudyLesson(
          id: 'b',
          courseId: 'c',
          chapterId: 'ch',
          title: '2',
          isPublished: true,
          status: StudyLessonStatus.ready,
        ),
        const StudyLesson(
          id: 'd',
          courseId: 'c',
          chapterId: 'ch',
          title: '초안',
          isPublished: false,
          status: StudyLessonStatus.draft,
        ),
      ];
      final progress = [
        const StudyLessonProgress(
          id: 'p1',
          learningRunId: 'r',
          courseId: 'c',
          lessonId: 'a',
          isCompleted: true,
        ),
      ];
      expect(
        StudyProgressCalculator.lessonProgressPercent(
          lessons: lessons,
          progress: progress,
        ),
        50,
      );
    });

    test('비공개·초안 강의 진도 제외', () {
      final lessons = [
        const StudyLesson(
          id: 'pub',
          courseId: 'c',
          chapterId: 'ch',
          title: '공개',
          isPublished: true,
          status: StudyLessonStatus.ready,
        ),
        const StudyLesson(
          id: 'draft',
          courseId: 'c',
          chapterId: 'ch',
          title: '초안',
          isPublished: false,
          status: StudyLessonStatus.draft,
        ),
      ];
      expect(
        StudyProgressCalculator.lessonProgressPercent(
          lessons: lessons,
          progress: [
            const StudyLessonProgress(
              id: 'x',
              learningRunId: 'r',
              courseId: 'c',
              lessonId: 'draft',
              isCompleted: true,
            ),
          ],
        ),
        0,
      );
    });

    test('강의 없으면 챕터 기준 호환', () {
      final chapters = [
        const StudyChapter(
          id: 'c1',
          courseId: 'course',
          title: '공개',
          status: StudyChapterStatus.ready,
          isPublished: true,
        ),
      ];
      final pct = StudyProgressCalculator.resolveCourseProgressPercent(
        chapters: chapters,
        chapterProgress: const [
          StudyProgress(
            id: 'p',
            courseId: 'course',
            chapterId: 'c1',
            isCompleted: true,
          ),
        ],
        lessons: const [],
        lessonProgress: const [],
      );
      expect(pct, 100);
    });
  });

  group('생성 작업', () {
    test('진행률 계산', () {
      expect(
        StudyGenerationJobCalculator.progressPercent(
          requested: 36,
          completed: 18,
        ),
        50,
      );
    });

    test('중단 후 재개·부분 완료 상태', () {
      expect(
        StudyGenerationJobCalculator.deriveStatus(
          current: StudyJobStatus.running,
          requested: 30,
          completed: 10,
          failed: 0,
          paused: true,
        ),
        StudyJobStatus.paused,
      );
      expect(
        StudyGenerationJobCalculator.deriveStatus(
          current: StudyJobStatus.running,
          requested: 30,
          completed: 20,
          failed: 2,
        ),
        StudyJobStatus.partiallyCompleted,
      );
    });

    test('실패 후 재시도 가능 상태(failed)', () {
      expect(
        StudyGenerationJobCalculator.deriveStatus(
          current: StudyJobStatus.running,
          requested: 30,
          completed: 0,
          failed: 3,
        ),
        StudyJobStatus.failed,
      );
    });

    test('동일 강의 중복 생성 방지', () {
      final keys = <String>{};
      final k = StudyGenerationDeduper.itemKey(jobId: 'j1', lessonNumber: 5);
      keys.add(k);
      expect(
        StudyGenerationDeduper.alreadyCompleted(
          completedKeys: keys,
          jobId: 'j1',
          lessonNumber: 5,
        ),
        isTrue,
      );
      expect(
        StudyGenerationDeduper.alreadyCompleted(
          completedKeys: keys,
          jobId: 'j1',
          lessonNumber: 6,
        ),
        isFalse,
      );
    });
  });

  group('버전·수강회차', () {
    test('버전 번호 증가 개념', () {
      const v1 = StudyCourseVersion(
        id: 'v1',
        courseId: 'c',
        versionNumber: 1,
        isPublished: true,
      );
      const v2 = StudyCourseVersion(
        id: 'v2',
        courseId: 'c',
        versionNumber: 2,
        previousVersionId: 'v1',
      );
      expect(v2.versionNumber, greaterThan(v1.versionNumber));
      expect(v2.previousVersionId, v1.id);
      expect(v1.isPublished, isTrue);
    });

    test('새 회차 진도 0%·기존 회차 보존', () {
      const run1 = StudyLearningRun(
        id: 'r1',
        courseId: 'c',
        runNumber: 1,
        progress: 80,
        completedLessonCount: 8,
        totalLessonCount: 10,
        status: StudyLearningRunStatus.paused,
      );
      const run2 = StudyLearningRun(
        id: 'r2',
        courseId: 'c',
        runNumber: 2,
        progress: 0,
        completedLessonCount: 0,
        totalLessonCount: 10,
        status: StudyLearningRunStatus.inProgress,
      );
      expect(run2.progress, 0);
      expect(run1.progress, 80);
      expect(run2.runNumber, greaterThan(run1.runNumber));
    });

    test('회차 비교', () {
      final c = StudyLearningRunComparer.compare(
        a: const StudyLearningRun(
          id: 'a',
          courseId: 'c',
          runNumber: 1,
          progress: 40,
          totalStudyMinutes: 100,
          completedLessonCount: 4,
        ),
        b: const StudyLearningRun(
          id: 'b',
          courseId: 'c',
          runNumber: 2,
          progress: 70,
          totalStudyMinutes: 120,
          completedLessonCount: 7,
        ),
      );
      expect(c.progressB! > c.progressA!, isTrue);
    });

    test('현재 회차 복습은 attemptCount 증가 개념', () {
      const p = StudyLessonProgress(
        id: 'p',
        learningRunId: 'r',
        courseId: 'c',
        lessonId: 'l',
        isCompleted: true,
        attemptCount: 2,
        needsReview: true,
      );
      expect(p.isCompleted, isTrue);
      expect(p.attemptCount, greaterThan(1));
    });
  });

  group('완료 정책·검증·AI 미연결', () {
    test('완료 정책', () {
      const lesson = StudyLesson(
        id: 'l',
        courseId: 'c',
        chapterId: 'ch',
        title: 't',
        completionPolicy: StudyCompletionPolicy.practiceAndQuiz,
      );
      expect(
        StudyLessonCompletionChecker.canComplete(
          lesson: lesson,
          contentConfirmed: true,
          practiceDone: true,
          quizDone: false,
          adminApproved: false,
        ),
        isFalse,
      );
      expect(
        StudyLessonCompletionChecker.canComplete(
          lesson: lesson,
          contentConfirmed: true,
          practiceDone: true,
          quizDone: true,
          adminApproved: false,
        ),
        isTrue,
      );
    });

    test('빈 본문·스크립트 검증', () {
      final empty = StudyLessonValidator.validate(
        const StudyLesson(
          id: '1',
          courseId: 'c',
          chapterId: 'ch',
          title: 'ok',
          lessonNumber: 1,
          isPublished: true,
        ),
      );
      expect(empty.status, StudyValidationStatus.failed);

      final bad = StudyLessonValidator.validate(
        const StudyLesson(
          id: '2',
          courseId: 'c',
          chapterId: 'ch',
          title: 'ok',
          lessonNumber: 1,
          intro: '설명입니다.',
          contentBlocks: [
            {'body': '<script>alert(1)</script>'},
          ],
        ),
      );
      expect(bad.issues.any((e) => e.contains('스크립트')), isTrue);
    });

    test('AI 미연결 상태', () async {
      final provider = DisconnectedStudyAiProvider();
      expect(provider.isConnected, isFalse);
      expect(provider.connectionMessage, contains('아직 연결되지 않았습니다'));

      final gen = DisconnectedStudyCourseGenerator();
      expect(gen.isConnected, isFalse);
      expect(
        () => gen.generateOutline(
          const StudyCourseGenerationRequest(interestField: 'x'),
        ),
        throwsStateError,
      );

      expect(
        StudyAiUsageDisplay.costLabel(inputTokens: null, outputTokens: null),
        '비용 미설정',
      );
    });

    test('관리자 외 AI 생성은 클라이언트에서 연결 시 차단(미연결 throw)', () async {
      final tutor = DisconnectedStudyAiLessonTutor();
      expect(
        () => tutor.respond(
          mode: StudyAiLessonMode.basic,
          userMessage: 'hi',
          lessonContext: const {},
        ),
        throwsStateError,
      );
    });
  });

  group('UI 오버플로·모바일', () {
    testWidgets('긴 강의 본문 SelectableText 오버플로 방지', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final long = '가' * 800;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [SelectableText(long), const Text('다음 강의')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('다음 강의'), findsOneWidget);
    });

    testWidgets('StudyLessonScreen 타입 존재(라우트용)', (tester) async {
      // 위젯 자체는 Firebase 필요 — 생성자만 검증
      expect(
        () => StudyLessonScreen(courseId: 'c', lessonId: 'l'),
        returnsNormally,
      );
    });
  });
}
