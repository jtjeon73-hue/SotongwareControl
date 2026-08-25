import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/remote_control_env.dart';
import '../models/remote_agent_models.dart';

class RemoteControlApiException implements Exception {
  RemoteControlApiException(this.userMessage, {this.code, this.statusCode});

  final String userMessage;
  final String? code;
  final int? statusCode;

  @override
  String toString() => userMessage;
}

class RemoteRunCancelResult {
  const RemoteRunCancelResult({
    required this.state,
    required this.operationId,
    this.idempotent = false,
  });

  final String state;
  final String operationId;
  final bool idempotent;

  bool get completed => state == 'completed';
}

class RemoteArtifactDownloadGrant {
  const RemoteArtifactDownloadGrant({
    required this.downloadUrl,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
  });

  final String downloadUrl;
  final String fileName;
  final String contentType;
  final int sizeBytes;
}

/// Control-plane HTTPS client (Firebase Auth ID Token). Never logs tokens.
class RemoteControlApi {
  RemoteControlApi({
    http.Client? httpClient,
    this._auth,
    String? Function()? baseUrl,
    this._idTokenProvider,
  }) : _http = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? (() => RemoteControlEnv.baseUrl);

  final http.Client _http;
  final FirebaseAuth? _auth;
  final String? Function() _baseUrl;
  final Future<String?> Function()? _idTokenProvider;

  Future<String> _token() async {
    final provider = _idTokenProvider;
    if (provider != null) {
      final t = await provider();
      if (t == null || t.isEmpty) {
        throw RemoteControlApiException(
          '로그인이 필요합니다. 다시 로그인해 주세요.',
          code: 'auth',
        );
      }
      return t;
    }
    User? user;
    try {
      user = (_auth ?? FirebaseAuth.instance).currentUser;
    } catch (_) {
      throw RemoteControlApiException('로그인이 필요합니다. 다시 로그인해 주세요.', code: 'auth');
    }
    if (user == null) {
      throw RemoteControlApiException('로그인이 필요합니다. 다시 로그인해 주세요.', code: 'auth');
    }
    try {
      final t = await user.getIdToken();
      if (t == null || t.isEmpty) {
        throw RemoteControlApiException(
          '인증이 만료되었습니다. 다시 로그인해 주세요.',
          code: 'auth',
        );
      }
      return t;
    } catch (e) {
      if (e is RemoteControlApiException) rethrow;
      throw RemoteControlApiException(
        '인증이 만료되었습니다. 다시 로그인해 주세요.',
        code: 'auth',
      );
    }
  }

  Uri _uri(String path) {
    final base = (_baseUrl() ?? RemoteControlEnv.productionBaseUrl).replaceAll(
      RegExp(r'/$'),
      '',
    );
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p');
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await _token();
    late http.Response res;
    try {
      res = await _http
          .post(
            _uri(path),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw RemoteControlApiException('전달 확인이 지연되고 있습니다.', code: 'timeout');
    } catch (_) {
      throw RemoteControlApiException(
        '서버에 연결할 수 없습니다. 네트워크를 확인해 주세요.',
        code: 'network',
      );
    }

    Map<String, dynamic> map = {};
    try {
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body);
      if (decoded is Map) {
        map = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    if (res.statusCode >= 200 && res.statusCode < 300 && map['ok'] == true) {
      return map;
    }

    final code = '${map['error'] ?? ''}';
    throw RemoteControlApiException(
      _userMessage(res.statusCode, code),
      code: code.isEmpty ? null : code,
      statusCode: res.statusCode,
    );
  }

  static String _userMessage(int status, String code) {
    if (status == 401 || code == 'unauthorized') {
      return '인증이 만료되었습니다. 다시 로그인해 주세요.';
    }
    if (status == 403 || code == 'forbidden') {
      return '이 작업을 수행할 권한이 없습니다.';
    }
    if (status == 404 || code == 'not_found') {
      return '요청한 대상을 찾을 수 없습니다.';
    }
    if (code == 'run_mismatch') {
      return '선택한 작업과 서버 작업 정보가 일치하지 않아 취소하지 않았습니다.';
    }
    if (code == 'agent_offline' || code == 'agent_missing') {
      return '전송 실패. 연결된 노트북 Agent가 없습니다. 다시 시도가 필요합니다.';
    }
    if (code == 'bad_pairing') {
      return '연결 코드가 올바르지 않거나 만료되었습니다.';
    }
    if (status >= 500) {
      return '서버 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.';
    }
    return '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
  }

  Future<RemoteArtifactDownloadGrant> createArtifactDownloadGrant({
    required String projectId,
    required String stageId,
    required int revision,
    required String fileName,
    String productType = 'ebook',
    String artifactFileName = 'final_ebook.pdf',
  }) async {
    final map = await _post('/api/control/artifact-download', {
      'projectId': projectId,
      'stageId': stageId,
      'revision': revision,
      'productType': productType,
      'fileName': artifactFileName,
      'downloadFileName': fileName,
    });
    final url = '${map['downloadUrl'] ?? ''}'.trim();
    final returnedName = '${map['fileName'] ?? ''}'.trim();
    final contentType = '${map['contentType'] ?? ''}'.trim();
    final sizeBytes = (map['sizeBytes'] is num)
        ? (map['sizeBytes'] as num).toInt()
        : int.tryParse('${map['sizeBytes'] ?? ''}') ?? 0;
    if (url.isEmpty ||
        returnedName.isEmpty ||
        contentType.isEmpty ||
        sizeBytes <= 0) {
      throw RemoteControlApiException(
        '결과물 다운로드 응답이 올바르지 않습니다.',
        code: 'invalid_download_grant',
      );
    }
    return RemoteArtifactDownloadGrant(
      downloadUrl: url,
      fileName: returnedName,
      contentType: contentType,
      sizeBytes: sizeBytes,
    );
  }

  Future<Uint8List> fetchArtifactPdf({
    required String projectId,
    required String stageId,
    required int revision,
  }) async {
    final token = await _token();
    late http.Response res;
    try {
      res = await _http
          .post(
            _uri('/api/control/artifact-view'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'projectId': projectId,
              'stageId': stageId,
              'revision': revision,
              'fileName': 'final_ebook.pdf',
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw RemoteControlApiException(
        'PDF 미리보기 준비가 지연되고 있습니다.',
        code: 'timeout',
      );
    } catch (_) {
      throw RemoteControlApiException('PDF 미리보기에 연결할 수 없습니다.', code: 'network');
    }

    final contentType = (res.headers['content-type'] ?? '')
        .split(';')
        .first
        .trim()
        .toLowerCase();
    if (res.statusCode >= 200 &&
        res.statusCode < 300 &&
        contentType == 'application/pdf' &&
        res.bodyBytes.isNotEmpty) {
      return res.bodyBytes;
    }

    var code = '';
    try {
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body);
      if (decoded is Map) code = '${decoded['error'] ?? ''}';
    } catch (_) {}
    throw RemoteControlApiException(
      _userMessage(res.statusCode, code),
      code: code.isEmpty ? 'invalid_pdf_preview' : code,
      statusCode: res.statusCode,
    );
  }

  Future<RemotePairingResult> createPairing() async {
    final map = await _post('/api/control/create-pairing', {});
    final exp = DateTime.tryParse('${map['expiresAt'] ?? ''}')?.toUtc();
    if (exp == null || '${map['pairingCode'] ?? ''}'.isEmpty) {
      throw RemoteControlApiException('연결 코드 응답이 올바르지 않습니다.');
    }
    return RemotePairingResult(
      sessionId: '${map['sessionId'] ?? ''}',
      pairingCode: '${map['pairingCode']}',
      expiresAt: exp,
      ttlSeconds: (map['ttlSeconds'] is num)
          ? (map['ttlSeconds'] as num).toInt()
          : 600,
    );
  }

  Future<void> registerNotificationToken({
    required String token,
    required String deviceId,
    String platform = 'web',
  }) async {
    await _post('/api/control/register-notification-token', {
      'token': token,
      'deviceId': deviceId,
      'platform': platform,
    });
  }

  Future<void> unregisterNotificationToken({required String deviceId}) async {
    await _post('/api/control/unregister-notification-token', {
      'deviceId': deviceId,
    });
  }

  Future<Map<String, dynamic>> notificationDiagnostics() =>
      _post('/api/control/notification-diagnostics', const {});

  Future<Map<String, dynamic>> sendTestNotification() =>
      _post('/api/control/send-test-notification', const {});

  Future<String> createJob({
    required String type,
    required String title,
    required String assignedAgentId,
    int totalStages = 18,
    String? instructionId,
  }) async {
    final body = <String, dynamic>{
      'type': type,
      'title': title,
      'assignedAgentId': assignedAgentId,
      'totalStages': totalStages,
    };
    final iid = (instructionId ?? '').trim();
    if (iid.isNotEmpty) body['instructionId'] = iid;
    final map = await _post('/api/control/create-job', body);
    final id = '${map['jobId'] ?? ''}';
    if (id.isEmpty) {
      throw RemoteControlApiException('작업 생성에 실패했습니다.');
    }
    return id;
  }

  Future<({String jobId, String commandId, String agentId, String outcome})>
  deliverInstruction({
    required String instructionId,
    required String type,
    required String title,
    required String assignedAgentId,
    required Map<String, dynamic> payload,
    int totalStages = 18,
  }) async {
    final map = await _post('/api/control/deliver-instruction', {
      'instructionId': instructionId,
      'type': type,
      'title': title,
      'assignedAgentId': assignedAgentId,
      'totalStages': totalStages,
      'payload': payload,
    });
    final jobId = '${map['jobId'] ?? ''}';
    final commandId = '${map['commandId'] ?? ''}';
    if (jobId.isEmpty || commandId.isEmpty) {
      throw RemoteControlApiException(
        '전송에 실패했습니다. 다시 시도해 주세요.',
        code: 'start_failed',
      );
    }
    return (
      jobId: jobId,
      commandId: commandId,
      agentId: '${map['agentId'] ?? assignedAgentId}',
      outcome: '${map['outcome'] ?? 'created'}',
    );
  }

  Future<({String commandId, String jobId, bool idempotent})> startJob({
    required String jobId,
    required Map<String, dynamic> payload,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{'jobId': jobId, 'payload': payload};
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      body['idempotencyKey'] = idempotencyKey;
    }
    final map = await _post('/api/control/start-job', body);
    return (
      commandId: '${map['commandId'] ?? ''}',
      jobId: '${map['jobId'] ?? jobId}',
      idempotent: map['idempotent'] == true,
    );
  }

  Future<RemoteRunCancelResult> cancelRun({
    required String jobId,
    required String instructionId,
    required String projectId,
    String message = '사용자 작업 취소',
  }) async {
    RemoteRunCancelResult? latest;
    for (var attempt = 0; attempt < 18; attempt += 1) {
      final map = await _post('/api/control/cancel-job', {
        'jobId': jobId,
        'instructionId': instructionId,
        'projectId': projectId,
        'message': message,
      });
      latest = RemoteRunCancelResult(
        state: '${map['state'] ?? 'cancel_requested'}',
        operationId: '${map['operationId'] ?? ''}',
        idempotent: map['idempotent'] == true,
      );
      if (latest.completed) return latest;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return latest ??
        const RemoteRunCancelResult(state: 'cancel_requested', operationId: '');
  }
}
