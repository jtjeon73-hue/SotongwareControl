import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sotong_ware_control/services/pdf_download_service.dart';
import 'package:sotong_ware_control/services/remote_control_api.dart';
import 'package:sotong_ware_control/widgets/pdf_download_button.dart';

void main() {
  final validPdf = Uint8List.fromList(<int>[
    ...'%PDF-1.7\n'.codeUnits,
    ...'test payload\n'.codeUnits,
    ...'%%EOF\n'.codeUnits,
  ]);

  group('artifact PDF preview API', () {
    test('sends Firebase auth and receives inline PDF bytes', () async {
      final api = RemoteControlApi(
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/control/artifact-view');
          expect(request.headers['Authorization'], 'Bearer viewer-token');
          expect(request.body, contains('wi_plan_123'));
          expect(request.body, contains('maintain'));
          return http.Response.bytes(
            validPdf,
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }),
        baseUrl: () => 'https://sotongware-control.web.app',
        idTokenProvider: () async => 'viewer-token',
      );

      final bytes = await api.fetchArtifactPdf(
        projectId: 'wi_plan_123',
        stageId: 'maintain',
        revision: 1,
      );
      expect(bytes, validPdf);
      expect(hasPdfSignature(bytes), isTrue);
      expect(hasPdfEof(bytes), isTrue);
    });

    test('rejects unauthenticated preview response', () async {
      final api = RemoteControlApi(
        httpClient: MockClient(
          (_) async => http.Response(
            '{"ok":false,"error":"unauthorized"}',
            401,
            headers: {'content-type': 'application/json'},
          ),
        ),
        baseUrl: () => 'https://sotongware-control.web.app',
        idTokenProvider: () async => 'expired-token',
      );

      await expectLater(
        api.fetchArtifactPdf(
          projectId: 'wi_plan_123',
          stageId: 'maintain',
          revision: 1,
        ),
        throwsA(
          isA<RemoteControlApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.code, 'code', 'unauthorized'),
        ),
      );
    });
  });

  group('ArtifactPdfDownloadService', () {
    test('opens an attachment grant with a safe readable filename', () async {
      String? requestedName;
      String? openedUrl;
      final service = ArtifactPdfDownloadService(
        grantProvider:
            ({
              required projectId,
              required stageId,
              required revision,
              required fileName,
            }) async {
              expect(projectId, 'wi_plan_123');
              expect(stageId, 'publish_prep');
              requestedName = fileName;
              return PdfDownloadGrant(
                downloadUrl:
                    'https://storage.googleapis.com/bucket/final.pdf?signature=attachment',
                fileName: fileName,
                contentType: 'application/pdf; charset=binary',
                sizeBytes: validPdf.length,
              );
            },
        attachmentOpener: (url) async => openedUrl = url,
      );

      final result = await service.downloadPdf(
        projectId: 'wi_plan_123',
        stageId: 'publish_prep',
        title: '모바일 결제/보안: 기초 전자책',
        revision: 1,
      );

      expect(result.ok, isTrue);
      expect(requestedName, '모바일_결제_보안_기초_전자책_r1.pdf');
      expect(openedUrl, contains('signature=attachment'));
      expect(result.sizeBytes, validPdf.length);
    });

    test('normalizes empty, unsafe and long filenames', () {
      expect(
        buildPdfDownloadFileName(title: r'<>:"/\|?*', revision: 0),
        'AI_전자책_최종본_r1.pdf',
      );
      expect(
        buildPdfDownloadFileName(title: '최종 본.pdf', revision: 2),
        '최종_본_r2.pdf',
      );
      expect(
        buildPdfDownloadFileName(title: '가' * 100, revision: 3).length,
        87,
      );
    });

    test('allows only signed-storage HTTPS hosts', () {
      expect(
        isAllowedArtifactDownloadUri(
          Uri.parse('https://storage.googleapis.com/bucket/final.pdf'),
        ),
        isTrue,
      );
      expect(
        isAllowedArtifactDownloadUri(
          Uri.parse('https://sotongware-control.firebasestorage.app/a.pdf'),
        ),
        isTrue,
      );
      for (final url in <String>[
        'http://storage.googleapis.com/a.pdf',
        'https://googleapis.com.evil.example/a.pdf',
        'file:///tmp/a.pdf',
        'https://localhost/a.pdf',
      ]) {
        expect(isAllowedArtifactDownloadUri(Uri.parse(url)), isFalse);
      }
    });

    test(
      'rejects wrong MIME, invalid size and an untrusted grant URL',
      () async {
        Future<PdfDownloadResult> run(PdfDownloadGrant grant) {
          return ArtifactPdfDownloadService(
            grantProvider:
                ({
                  required projectId,
                  required stageId,
                  required revision,
                  required fileName,
                }) async => grant,
            attachmentOpener: (_) async {
              fail('invalid grant must never reach the attachment opener');
            },
          ).downloadPdf(
            projectId: 'wi_plan_123',
            stageId: 'publish_prep',
            title: '전자책',
            revision: 1,
          );
        }

        expect(
          (await run(
            const PdfDownloadGrant(
              downloadUrl: 'https://storage.googleapis.com/bucket/final.pdf',
              fileName: 'ebook.pdf',
              contentType: 'text/html',
              sizeBytes: 20,
            ),
          )).ok,
          isFalse,
        );
        expect(
          (await run(
            const PdfDownloadGrant(
              downloadUrl: 'https://storage.googleapis.com/bucket/final.pdf',
              fileName: 'ebook.pdf',
              contentType: pdfMimeType,
              sizeBytes: 0,
            ),
          )).ok,
          isFalse,
        );
        expect(
          (await run(
            const PdfDownloadGrant(
              downloadUrl: 'https://evil.example/final.pdf',
              fileName: 'ebook.pdf',
              contentType: pdfMimeType,
              sizeBytes: 20,
            ),
          )).ok,
          isFalse,
        );
      },
    );

    test('validates PDF signature, EOF and preserves the original bytes', () {
      final copied = Uint8List.fromList(validPdf);
      expect(hasPdfSignature(copied), isTrue);
      expect(hasPdfEof(copied), isTrue);
      expect(copied, orderedEquals(validPdf));
      expect(
        hasPdfSignature(Uint8List.fromList('not-pdf%%EOF'.codeUnits)),
        isFalse,
      );
      expect(
        hasPdfEof(Uint8List.fromList('%PDF-1.7 no eof'.codeUnits)),
        isFalse,
      );
    });
  });

  testWidgets('PDF download button invokes the download action', (
    tester,
  ) async {
    final fake = _FakeDownloader();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PdfDownloadButton(
            projectId: 'wi_plan_123',
            stageId: 'publish_prep',
            title: 'AI 전자책 최종본',
            revision: 2,
            downloader: fake,
          ),
        ),
      ),
    );

    await tester.tap(find.text('PDF 다운로드'));
    await tester.pumpAndSettle();

    expect(fake.calls, 1);
    expect(fake.lastProjectId, 'wi_plan_123');
    expect(fake.lastStageId, 'publish_prep');
    expect(fake.lastTitle, 'AI 전자책 최종본');
    expect(fake.lastRevision, 2);
    expect(find.textContaining('다운로드를 시작했습니다.'), findsOneWidget);
  });
}

class _FakeDownloader implements PdfDownloader {
  int calls = 0;
  String lastProjectId = '';
  String lastStageId = '';
  String lastTitle = '';
  int lastRevision = 0;

  @override
  Future<PdfDownloadResult> downloadPdf({
    required String projectId,
    required String stageId,
    required String title,
    required int revision,
  }) async {
    calls++;
    lastProjectId = projectId;
    lastStageId = stageId;
    lastTitle = title;
    lastRevision = revision;
    return PdfDownloadResult.success(
      fileName: 'AI_전자책_최종본_r$revision.pdf',
      sizeBytes: 20,
    );
  }
}
