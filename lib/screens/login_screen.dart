import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/control_theme.dart';
import '../widgets/sotong_brand_icon.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authService});

  final AuthClient authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _keepSignedIn = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String _messageFor(AuthFailureReason reason) {
    switch (reason) {
      case AuthFailureReason.emptyId:
      case AuthFailureReason.emptyPassword:
        return '아이디와 비밀번호를 입력해 주세요.';
      case AuthFailureReason.configMissing:
        return '관리자 인증 설정이 완료되지 않았습니다.';
      case AuthFailureReason.unauthorized:
        return '관리자 권한이 없는 계정입니다.';
      case AuthFailureReason.invalidId:
      case AuthFailureReason.invalidCredentials:
      case AuthFailureReason.unknown:
        return '아이디 또는 비밀번호를 확인해 주세요.';
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await widget.authService.signIn(
      adminId: _idController.text,
      password: _passwordController.text,
      keepSignedIn: _keepSignedIn,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = _messageFor(result.failure!);
        _passwordController.clear();
      });
      return;
    }

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isNarrow = size.width < 480;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1C2C), Color(0xFF0F2F3A), Color(0xFF134E4A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 20 : 32,
                vertical: 28,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SotongBrandIcon(size: 88),
                    const SizedBox(height: 20),
                    Text(
                      '소통웨어 총괄관제',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '전체 사업과 AI 조직을 통합 관리하는\n관리자 전용 디지털 관제 시스템',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '관리자 로그인',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: ControlColors.deepNavy),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '허가된 관리자만 접속할 수 있습니다.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: ControlColors.textMuted),
                            ),
                            const SizedBox(height: 22),
                            TextField(
                              controller: _idController,
                              enabled: !_isSubmitting,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              decoration: const InputDecoration(
                                labelText: '아이디',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _passwordFocus.requestFocus(),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              enabled: !_isSubmitting,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: '비밀번호',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? '비밀번호 표시'
                                      : '비밀번호 숨김',
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              onSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 10),
                            Material(
                              color: Colors.transparent,
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                value: _keepSignedIn,
                                onChanged: _isSubmitting
                                    ? null
                                    : (value) => setState(
                                        () => _keepSignedIn = value ?? false,
                                      ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: const Text(
                                  '이 기기에서 로그인 상태 유지',
                                  style: TextStyle(fontSize: 13),
                                ),
                                subtitle: const Text(
                                  '공용 PC에서는 체크하지 마세요.',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: ControlColors.accentRose.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: ControlColors.accentRose.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: ControlColors.accentRose,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                onPressed: _isSubmitting ? null : _submit,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('로그인'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'PRIVATE · 소통총관제',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
