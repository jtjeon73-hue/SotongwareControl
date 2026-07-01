import 'package:flutter/material.dart';
import '../models/department.dart';
import '../theme/control_theme.dart';

class DepartmentStatusCard extends StatelessWidget {
  const DepartmentStatusCard({super.key, required this.department, this.onTap});

  final Department department;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ControlColors.accentWarm.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.groups_outlined,
                      color: ControlColors.accentWarm,
                      size: 18,
                    ),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: ControlColors.textMuted,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                department.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '역할: ${department.role}',
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (department.taskCards.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '${department.taskCards.length}개 업무 영역',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: ControlColors.accentWarm,
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
