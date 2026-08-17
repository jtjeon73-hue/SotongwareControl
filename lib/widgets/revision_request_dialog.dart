import 'package:flutter/material.dart';

/// 모바일(좁은 viewport)에서는 전체화면 editor, desktop/tablet은 Dialog.
const double revisionRequestMobileBreakpoint = 600;

bool revisionRequestUsesMobileLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).width < revisionRequestMobileBreakpoint;
}

/// 「보완 요청」 — 모바일 full-screen / desktop Dialog.
Future<String?> showRevisionRequestDialog(BuildContext context) {
  if (revisionRequestUsesMobileLayout(context)) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => const RevisionRequestMobileScreen(),
      ),
    );
  }
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    useSafeArea: false,
    builder: (dialogContext) => const RevisionRequestDialog(),
  );
}

/// 공통 입력 상태 — controller·focus·submit (한글 IME 안전).
abstract class RevisionRequestEditorState<T extends RevisionRequestEditor>
    extends State<T> {
  late final TextEditingController controller;
  late final FocusNode focusNode;
  bool submitting = false;

  /// 테스트용 — controller 인스턴스 안정성 검증.
  TextEditingController get debugController => controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
    focusNode = FocusNode();
  }

  @override
  void dispose() {
    focusNode.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (submitting) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;
    setState(() => submitting = true);
    if (!mounted) return;
    Navigator.of(context).pop(text);
  }

  void cancel() {
    if (submitting) return;
    Navigator.of(context).pop();
  }

  Widget buildGuideText(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      widget.mobileLayout
          ? 'Agent가 반영할 보완 내용을 입력하세요.'
          : 'Agent가 반영할 보완 내용을 구체적으로 적어 주세요.',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.35,
      ),
    );
  }

  Widget buildTextField(BuildContext context) {
    return TextField(
      key: const Key('revision_request_field'),
      controller: controller,
      focusNode: focusNode,
      autofocus: !widget.mobileLayout,
      expands: widget.mobileLayout,
      maxLines: widget.mobileLayout ? null : null,
      minLines: widget.mobileLayout ? null : null,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: '보완할 내용을 입력하세요.',
        alignLabelWithHint: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget buildSubmitButton({required bool fullWidth}) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final canSubmit = value.text.trim().isNotEmpty && !submitting;
        final child = submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(widget.mobileLayout ? '보완 요청 보내기' : '요청');
        if (fullWidth) {
          return FilledButton(
            key: const Key('revision_request_submit'),
            onPressed: canSubmit ? submit : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: child,
          );
        }
        return FilledButton(
          key: const Key('revision_request_submit'),
          onPressed: canSubmit ? submit : null,
          child: child,
        );
      },
    );
  }
}

abstract class RevisionRequestEditor extends StatefulWidget {
  const RevisionRequestEditor({super.key, required this.mobileLayout});

  final bool mobileLayout;
}

/// 모바일 전체화면 — Scaffold resize로 Samsung keyboard 대응.
class RevisionRequestMobileScreen extends RevisionRequestEditor {
  const RevisionRequestMobileScreen({super.key}) : super(mobileLayout: true);

  @override
  RevisionRequestMobileScreenState createState() =>
      RevisionRequestMobileScreenState();
}

class RevisionRequestMobileScreenState
    extends RevisionRequestEditorState<RevisionRequestMobileScreen> {
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !submitting,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Scaffold(
          key: const Key('revision_request_mobile_screen'),
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            leading: IconButton(
              key: const Key('revision_request_cancel'),
              icon: const Icon(Icons.arrow_back),
              tooltip: '취소',
              onPressed: submitting ? null : cancel,
            ),
            title: const Text('보완 요청'),
            centerTitle: false,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildGuideText(context),
                  const SizedBox(height: 12),
                  Expanded(child: buildTextField(context)),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: buildSubmitButton(fullWidth: true),
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop/tablet Dialog.
class RevisionRequestDialog extends RevisionRequestEditor {
  const RevisionRequestDialog({super.key}) : super(mobileLayout: false);

  @override
  RevisionRequestDialogState createState() => RevisionRequestDialogState();
}

class RevisionRequestDialogState
    extends RevisionRequestEditorState<RevisionRequestDialog> {
  static const double _maxDialogWidth = 400;
  static const double _fieldHeight = 168;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      key: const Key('revision_request_desktop_dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SafeArea(
        child: Material(
          color: theme.colorScheme.surface,
          elevation: 8,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxDialogWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '보완 요청',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  buildGuideText(context),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: _fieldHeight,
                    child: buildTextField(context),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        key: const Key('revision_request_cancel'),
                        onPressed: submitting ? null : cancel,
                        child: const Text('취소'),
                      ),
                      const Spacer(),
                      buildSubmitButton(fullWidth: false),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
