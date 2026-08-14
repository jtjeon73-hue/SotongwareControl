import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/business_planning.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/services/plan_execution_index.dart';
import 'package:sotong_ware_control/widgets/project_design/plan_library_panel.dart';

BusinessPlanDocument _plan({
  required String id,
  required String topic,
  String instructionId = '',
  bool isProtected = false,
  String status = PlanningStatus.draft,
  String libraryState = PlanLibraryState.active,
  List<String> tags = const [],
}) {
  return BusinessPlanDocument(
    id: id,
    status: status,
    version: 1,
    createdAt: '2026-08-14T00:00:00.000Z',
    updatedAt: '2026-08-14T00:00:00.000Z',
    input: BusinessPlanInput(
      topic: topic,
      customerProblem: '문제',
      targetCustomer: '고객',
      desiredOutcome: '목적',
      artifactType: ArtifactType.ebook,
      deliverableTypes: const [ArtifactType.ebook],
    ),
    instructionId: instructionId.isEmpty ? 'wi_$id' : instructionId,
    isProtected: isProtected,
    libraryState: libraryState,
    tags: tags,
  );
}

Sotong24RemoteProject _opsRemoteProject() {
  return Sotong24RemoteProject(
    projectId: 'wi_plan_1785905165067',
    title: '50대 초보도 따라 하는 AI 전자책 첫 출간',
    productType: ArtifactType.ebook,
    currentStage: 18,
    totalStages: 18,
    progress: 90,
    status: Sotong24WorkStatus.awaitingApproval,
    approvalStatus: ApprovalStatus.pending,
    startedAt: '2026-08-06T10:10:00+09:00',
  );
}

PlanExecutionIndex _opsExecutionIndex() {
  return PlanExecutionIndex.fromRemoteProjects([_opsRemoteProject()]);
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required List<BusinessPlanDocument> plans,
  required String folderFilter,
  required PlanLibraryViewMode viewMode,
  ValueChanged<String>? onFolderChanged,
  Future<void> Function(PlanLibraryBulkAction, List<BusinessPlanDocument>)?
  onBulkAction,
  PlanExecutionIndex? executionIndex,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PlanLibraryPanel(
            plans: plans,
            activePlanId: null,
            folderFilter: folderFilter,
            searchQuery: '',
            viewMode: viewMode,
            sort: PlanLibrarySort.newest,
            onFolderChanged: onFolderChanged ?? (_) {},
            onSearchChanged: (_) {},
            onViewModeChanged: (_) {},
            onSortChanged: (_) {},
            onOpenPlan: (_) {},
            onToggleFavorite: (_) {},
            onStartNew: () {},
            onBulkAction: onBulkAction ?? (_, _) async {},
            executionIndex: executionIndex,
          ),
        ),
      ),
    ),
  );
}

Finder _enabledCheckboxForTopic(String topic) {
  return find.descendant(
    of: find.ancestor(
      of: find.text(topic),
      matching: find.byType(InkWell),
    ),
    matching: find.byWidgetPredicate(
      (w) => w is Checkbox && w.onChanged != null,
    ),
  );
}

Finder _disabledCheckboxForTopic(String topic) {
  return find.descendant(
    of: find.ancestor(
      of: find.text(topic),
      matching: find.byType(InkWell),
    ),
    matching: find.byWidgetPredicate(
      (w) => w is Checkbox && w.onChanged == null,
    ),
  );
}

void main() {
  testWidgets('기본 필터는 현재 라벨이며 관리 모드에서만 다중선택 UI', (tester) async {
    final plans = [
      _plan(id: 'a', topic: '정리용 A'),
      _plan(id: 'b', topic: '정리용 B'),
      _plan(
        id: 'ops',
        topic: '가이드 전자책개발',
        instructionId: 'wi_plan_1785905165067',
        status: PlanningStatus.transferred,
        tags: const ['보류'],
      ),
    ];
    PlanLibraryBulkAction? lastAction;
    List<BusinessPlanDocument>? lastSelected;

    await _pumpPanel(
      tester,
      plans: plans,
      folderFilter: 'all',
      viewMode: PlanLibraryViewMode.cards,
      executionIndex: _opsExecutionIndex(),
      onBulkAction: (action, selected) async {
        lastAction = action;
        lastSelected = selected;
      },
    );

    expect(find.text('현재'), findsOneWidget);
    expect(find.text('전체'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.text('관리'));
    await tester.pumpAndSettle();

    expect(find.text('선택 0개'), findsOneWidget);
    expect(find.text('전체 선택'), findsOneWidget);
    expect(find.text('선택 해제'), findsOneWidget);
    expect(find.text('선택 항목 보관'), findsOneWidget);
    expect(find.byType(Checkbox), findsWidgets);
    expect(_disabledCheckboxForTopic('50대 초보도 따라 하는 AI 전자책 첫 출간'), findsOneWidget);

    await tester.tap(find.text('전체 선택'));
    await tester.pumpAndSettle();
    expect(find.text('선택 2개'), findsOneWidget);

    await tester.tap(find.text('선택 항목 보관'));
    await tester.pumpAndSettle();
    expect(find.textContaining('선택한 2개의 기획을 보관하시겠습니까?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('보관'),
      ),
    );
    await tester.pumpAndSettle();

    expect(lastAction, PlanLibraryBulkAction.archive);
    expect(lastSelected!.map((p) => p.id).toSet(), {'a', 'b'});
  });

  testWidgets('보관 화면: archived plan 선택·보관 해제', (tester) async {
    final plans = [
      _plan(
        id: 'arch1',
        topic: '보관된 기획',
        libraryState: PlanLibraryState.archived,
      ),
    ];
    PlanLibraryBulkAction? lastAction;
    List<BusinessPlanDocument>? lastSelected;

    await _pumpPanel(
      tester,
      plans: plans,
      folderFilter: 'archived',
      viewMode: PlanLibraryViewMode.cards,
      onBulkAction: (action, selected) async {
        lastAction = action;
        lastSelected = selected;
      },
    );

    await tester.tap(find.text('관리'));
    await tester.pumpAndSettle();

    expect(find.text('선택 항목 보관 해제'), findsOneWidget);
    expect(_enabledCheckboxForTopic('보관된 기획'), findsOneWidget);

    await tester.tap(_enabledCheckboxForTopic('보관된 기획'));
    await tester.pumpAndSettle();
    expect(find.text('선택 1개'), findsOneWidget);

    await tester.tap(find.text('선택 항목 보관 해제'));
    await tester.pumpAndSettle();

    expect(lastAction, PlanLibraryBulkAction.unarchive);
    expect(lastSelected!.map((p) => p.id), ['arch1']);
  });

  testWidgets('휴지통 화면: trashed plan 선택·복원', (tester) async {
    final plans = [
      _plan(
        id: 'tr1',
        topic: '휴지통 기획',
        libraryState: PlanLibraryState.trashed,
      ),
    ];
    PlanLibraryBulkAction? lastAction;
    List<BusinessPlanDocument>? lastSelected;

    await _pumpPanel(
      tester,
      plans: plans,
      folderFilter: 'trashed',
      viewMode: PlanLibraryViewMode.cards,
      onBulkAction: (action, selected) async {
        lastAction = action;
        lastSelected = selected;
      },
    );

    await tester.tap(find.text('관리'));
    await tester.pumpAndSettle();

    expect(find.text('선택 항목 복원'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.onChanged, isNotNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('선택 1개'), findsOneWidget);

    await tester.tap(find.text('선택 항목 복원'));
    await tester.pumpAndSettle();

    expect(lastAction, PlanLibraryBulkAction.restore);
    expect(lastSelected!.map((p) => p.id), ['tr1']);
  });

  testWidgets('보호 기획은 현재 화면 archive 선택만 disabled (카드)', (tester) async {
    final plans = [
      _plan(id: 'ok', topic: '일반 기획'),
      _plan(
        id: 'ops',
        topic: '운영 WI',
        instructionId: 'wi_plan_1785905165067',
        status: PlanningStatus.transferred,
      ),
      _plan(id: 'prot', topic: '보호 기획', isProtected: true),
      _plan(
        id: 'work',
        topic: '작업중',
        status: PlanningStatus.inProgress,
      ),
    ];

    await _pumpPanel(
      tester,
      plans: plans,
      folderFilter: 'all',
      viewMode: PlanLibraryViewMode.cards,
      executionIndex: _opsExecutionIndex(),
    );
    await tester.tap(find.text('관리'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) => w is Checkbox && w.onChanged != null,
      ),
      findsNWidgets(2),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Checkbox && w.onChanged == null,
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('필터 전환 시 선택 상태 초기화', (tester) async {
    var folderFilter = 'all';
    final plans = [
      _plan(id: 'a', topic: '정리용 A'),
      _plan(
        id: 'arch1',
        topic: '보관된 기획',
        libraryState: PlanLibraryState.archived,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: PlanLibraryPanel(
                  plans: plans,
                  activePlanId: null,
                  folderFilter: folderFilter,
                  searchQuery: '',
                  viewMode: PlanLibraryViewMode.cards,
                  sort: PlanLibrarySort.newest,
                  onFolderChanged: (f) => setState(() {
                    folderFilter = f;
                  }),
                  onSearchChanged: (_) {},
                  onViewModeChanged: (_) {},
                  onSortChanged: (_) {},
                  onOpenPlan: (_) {},
                  onToggleFavorite: (_) {},
                  onStartNew: () {},
                  onBulkAction: (_, _) async {},
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('관리'));
    await tester.pumpAndSettle();
    await tester.tap(_enabledCheckboxForTopic('정리용 A'));
    await tester.pumpAndSettle();
    expect(find.text('선택 1개'), findsOneWidget);

    await tester.tap(find.text('보관'));
    await tester.pumpAndSettle();
    expect(find.text('선택 0개'), findsOneWidget);
  });
}
