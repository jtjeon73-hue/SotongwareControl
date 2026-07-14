import 'package:flutter/material.dart';

import '../../models/study/study_enums.dart';
import '../../models/study/study_models.dart';
import '../../services/firebase_ready.dart';
import '../../services/study/study_dashboard_service.dart';
import '../../services/study/study_repository.dart';
import '../../widgets/ops_ui.dart';
import '../../widgets/page_hero.dart';
import '../../widgets/study/study_widgets.dart';
import 'study_course_detail_screen.dart';

class StudyCoursesScreen extends StatefulWidget {
  const StudyCoursesScreen({super.key});

  @override
  State<StudyCoursesScreen> createState() => _StudyCoursesScreenState();
}

class _StudyCoursesScreenState extends State<StudyCoursesScreen> {
  final _repo = StudyRepository();
  final _query = TextEditingController();
  String? _category;
  String? _status;
  String? _difficulty;
  String _sort = 'recent';
  bool _grid = true;
  int _page = 0;
  static const _pageSize = 12;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePanel(
          title: '내 강의방',
          message: 'Firebase 연결 후 강의방을 확인할 수 있습니다.',
        ),
      );
    }

    return StreamBuilder<List<StudyCourse>>(
      stream: _repo.watchCourses(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyStatePanel(title: '로딩 오류', message: '${snap.error}'),
          );
        }
        final all = snap.data ?? const [];
        final categories =
            all
                .map((e) => e.category)
                .where((e) => e.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        final filtered = StudyCourseFilter.apply(
          courses: all,
          query: _query.text,
          category: _category,
          status: _status,
          difficulty: _difficulty,
          sort: _sort,
        );
        final pageCount = (filtered.length / _pageSize).ceil().clamp(1, 9999);
        if (_page >= pageCount) _page = 0;
        final pageItems = filtered
            .skip(_page * _pageSize)
            .take(_pageSize)
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHero(
                title: '내 강의방',
                subtitle:
                    '강의 개수는 제한되지 않습니다. 검색·필터로 관리하십시오. '
                    '가상 강의는 자동 생성하지 않습니다.',
                badge: '소통스터디부',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _query,
                      decoration: const InputDecoration(
                        labelText: '검색',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() => _page = 0),
                    ),
                  ),
                  DropdownButton<String?>(
                    value: _category,
                    hint: const Text('분야'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('전체 분야')),
                      ...categories.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      _category = v;
                      _page = 0;
                    }),
                  ),
                  DropdownButton<String?>(
                    value: _status,
                    hint: const Text('상태'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('전체 상태')),
                      ...[
                        StudyCourseStatus.draft,
                        StudyCourseStatus.ready,
                        StudyCourseStatus.inProgress,
                        StudyCourseStatus.paused,
                        StudyCourseStatus.completed,
                      ].map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(StudyCourseStatus.labelKo(s)),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      _status = v;
                      _page = 0;
                    }),
                  ),
                  DropdownButton<String?>(
                    value: _difficulty,
                    hint: const Text('난이도'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('전체 난이도'),
                      ),
                      ...[
                        StudyDifficulty.beginner,
                        StudyDifficulty.intermediate,
                        StudyDifficulty.advanced,
                      ].map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text(StudyDifficulty.labelKo(d)),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      _difficulty = v;
                      _page = 0;
                    }),
                  ),
                  DropdownButton<String>(
                    value: _sort,
                    items: const [
                      DropdownMenuItem(value: 'recent', child: Text('최근 학습순')),
                      DropdownMenuItem(value: 'progress', child: Text('진도율순')),
                      DropdownMenuItem(value: 'name', child: Text('이름순')),
                      DropdownMenuItem(value: 'favorite', child: Text('즐겨찾기')),
                    ],
                    onChanged: (v) => setState(() => _sort = v ?? 'recent'),
                  ),
                  IconButton(
                    tooltip: _grid ? '목록 보기' : '카드 보기',
                    onPressed: () => setState(() => _grid = !_grid),
                    icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _query.clear();
                      _category = null;
                      _status = null;
                      _difficulty = null;
                      _sort = 'recent';
                      _page = 0;
                    }),
                    child: const Text('필터 초기화'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('표시 ${pageItems.length} / 전체 ${filtered.length}건'),
              const SizedBox(height: 8),
              if (filtered.isEmpty)
                const EmptyStatePanel(
                  title: '표시할 강의방이 없습니다',
                  message: '스터디 관리에서 강의방을 생성하거나 필터를 초기화하십시오.',
                )
              else if (_grid)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: pageItems
                      .map(
                        (c) => SizedBox(
                          width: 320,
                          child: StudyCourseCard(
                            course: c,
                            onOpen: () => _open(c.id),
                            onToggleFavorite: () async {
                              await _repo.upsertCourse(
                                StudyCourse(
                                  id: c.id,
                                  title: c.title,
                                  category: c.category,
                                  description: c.description,
                                  learningGoal: c.learningGoal,
                                  targetLevel: c.targetLevel,
                                  difficulty: c.difficulty,
                                  status: c.status,
                                  iconName: c.iconName,
                                  isFavorite: !c.isFavorite,
                                  chapterCount: c.chapterCount,
                                  completedChapterCount:
                                      c.completedChapterCount,
                                  progress: c.progress,
                                  nextAction: c.nextAction,
                                  tags: c.tags,
                                  lastStudiedAt: c.lastStudiedAt,
                                ),
                              );
                            },
                          ),
                        ),
                      )
                      .toList(),
                )
              else
                ...pageItems.map(
                  (c) => ListTile(
                    title: Text(c.title),
                    subtitle: Text(
                      '${StudyCourseStatus.labelKo(c.status)} · ${c.category} · '
                      '진도 ${c.progress == null ? '미설정' : '${c.progress}%'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(c.id),
                  ),
                ),
              if (filtered.length > _pageSize) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: _page == 0
                          ? null
                          : () => setState(() => _page--),
                      child: const Text('이전'),
                    ),
                    Text('${_page + 1} / $pageCount'),
                    TextButton(
                      onPressed: _page + 1 >= pageCount
                          ? null
                          : () => setState(() => _page++),
                      child: const Text('다음'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _open(String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyCourseDetailScreen(courseId: id),
      ),
    );
  }
}
