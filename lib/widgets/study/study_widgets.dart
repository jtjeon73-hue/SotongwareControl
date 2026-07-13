import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/study/study_enums.dart';
import '../../models/study/study_models.dart';
import '../../theme/control_theme.dart';
import '../ops_ui.dart';

class StudyCourseCard extends StatelessWidget {
  const StudyCourseCard({
    super.key,
    required this.course,
    this.onOpen,
    this.onToggleFavorite,
    this.compact = false,
  });

  final StudyCourse course;
  final VoidCallback? onOpen;
  final VoidCallback? onToggleFavorite;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final progressLabel = course.progress == null
        ? '진행률 미설정'
        : '${course.progress}%';
    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: '즐겨찾기',
                    icon: Icon(
                      course.isFavorite ? Icons.star : Icons.star_border,
                      color: course.isFavorite
                          ? ControlColors.accentWarm
                          : ControlColors.textMuted,
                    ),
                    onPressed: onToggleFavorite,
                  ),
                ],
              ),
              if (course.description.isNotEmpty)
                Text(
                  course.description,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ControlColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusBadge(
                    label: StudyCourseStatus.labelKo(course.status),
                  ),
                  if (course.category.isNotEmpty)
                    StatusBadge(label: course.category),
                  StatusBadge(
                    label: StudyDifficulty.labelKo(course.difficulty),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '챕터 ${course.completedChapterCount}/${course.chapterCount} · $progressLabel',
              ),
              Text(
                '최근 학습: ${course.lastStudiedAt == null ? '없음' : DateFormat('yyyy-MM-dd').format(course.lastStudiedAt!)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: ControlColors.textMuted,
                ),
              ),
              Text(
                '다음: ${course.nextAction.isEmpty ? '첫 챕터를 등록하십시오.' : course.nextAction}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              if (onOpen != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: onOpen,
                    child: const Text('강의방 입장'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class StudyChapterTile extends StatelessWidget {
  const StudyChapterTile({
    super.key,
    required this.chapter,
    this.progress,
    this.onOpen,
  });

  final StudyChapter chapter;
  final StudyProgress? progress;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onOpen,
        title: Text(
          '${chapter.chapterNumber}. ${chapter.title}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            StudyChapterStatus.labelKo(chapter.status),
            if (progress?.isCompleted == true) '완료',
            if (progress != null)
              StudyUnderstanding.labelKo(progress!.understandingLevel),
            if (progress?.needsReview == true) '복습 필요',
            if (chapter.description.isNotEmpty) chapter.description,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: onOpen == null
            ? null
            : TextButton(onPressed: onOpen, child: const Text('입장')),
      ),
    );
  }
}

Future<void> showStudyConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required VoidCallback onConfirm,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('확인'),
        ),
      ],
    ),
  );
  if (ok == true) onConfirm();
}
