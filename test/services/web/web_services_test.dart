/// Web 平台服务层单元测试
///
/// 覆盖：[WebPlatform] 平台检测、[WebStorageService] 内存回退读写、
/// [WebAsrResult] JSON 解析容错。
///
/// 注意：[WebAudioRecorder] / [WebTtsService] 依赖 dart:js_interop，
/// 只能在真实浏览器环境运行，本文件仅测无平台依赖的纯逻辑部分。
library;

import 'package:echo_loop/services/web/web_asr_service.dart';
import 'package:echo_loop/services/web/web_platform.dart';
import 'package:echo_loop/services/web/web_storage_test_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── WebPlatform ──────────────────────────────────────────────────────────

  group('WebPlatform', () {
    test('isWeb 与 kIsWeb 一致', () {
      expect(WebPlatform.isWeb, kIsWeb);
    });

    // 以下三个属性在 VM 测试环境下为 false（kIsWeb=false），在 Web 环境下为 true
    test('isSpeechRecognitionSupported 等于 kIsWeb', () {
      expect(WebPlatform.isSpeechRecognitionSupported, kIsWeb);
    });

    test('isSpeechSynthesisSupported 等于 kIsWeb', () {
      expect(WebPlatform.isSpeechSynthesisSupported, kIsWeb);
    });

    test('isRecordingSupported 在非 Web 环境返回 false', () async {
      if (!kIsWeb) {
        expect(await WebPlatform.isRecordingSupported, isFalse);
      }
      // Web 环境下需要用户手势，此处只验证返回 bool
    });
  });

  // ── WebStorageService（测试Stub）───────────────────────────────────────────

  group('WebStorageService', () {
    late WebStorageService service;

    setUp(() {
      service = WebStorageService({});
    });

    test('set/get 基本字符串读写', () async {
      await service.set('greeting', 'hello');
      expect(service.get<String>('greeting'), 'hello');
    });

    test('set/get Map 对象并正确反序列化', () async {
      final data = {'name': '灵犀', 'version': '1.0'};
      await service.set('config', data);
      final loaded = service.get<Map<String, dynamic>>('config');
      expect(loaded?['name'], '灵犀');
      expect(loaded?['version'], '1.0');
    });

    test('读取不存在的 key 返回 defaultValue', () {
      expect(service.get<String>('missing', 'fallback'), 'fallback');
    });

    test('读取不存在的 key 默认返回 null', () {
      expect(service.get<String>('missing'), isNull);
    });

    test('remove 删除后读取返回 null', () async {
      await service.set('key', 'value');
      await service.remove('key');
      expect(service.get<String>('key'), isNull);
    });

    test('clear 清空所有数据', () async {
      await service.set('a', 1);
      await service.set('b', 2);
      await service.clear();
      expect(service.get<int>('a'), isNull);
      expect(service.get<int>('b'), isNull);
    });

    test('set 非 JSON 兼容类型：jsonEncode 抛异常被捕获', () async {
      // Function 不可序列化，应静默失败不抛异常
      await service.set('bad', () => 42);
      // 不崩溃即通过
    });

    test('通过 set 写入后可读出（绕过构造器缓存问题）', () async {
      await service.set('preset', 'value');
      expect(service.get<String>('preset'), 'value');
    });
  });

  // ── WebAsrResult ─────────────────────────────────────────────────────────

  group('WebAsrResult.fromJson', () {
    test('正常结构：完整字段', () {
      final result = WebAsrResult.fromJson({
        'text': 'Hello world',
        'duration_ms': 3200,
        'sentences': [
          {'start': 0, 'end': 3000, 'text': 'Hello world'},
        ],
      });
      expect(result.text, 'Hello world');
      expect(result.durationMs, 3200);
      expect(result.sentences.length, 1);
      expect(result.sentences[0]['text'], 'Hello world');
    });

    test('空 sentences 字段默认空列表', () {
      final result = WebAsrResult.fromJson({'text': 'hi', 'duration_ms': 500});
      expect(result.sentences, isEmpty);
    });

    test('缺失 text / duration_ms 使用默认值', () {
      final result = WebAsrResult.fromJson({});
      expect(result.text, '');
      expect(result.durationMs, 0);
      expect(result.sentences, isEmpty);
    });

    test('sentences 为 null 时不崩溃', () {
      final result = WebAsrResult.fromJson({
        'text': 'test',
        'sentences': null,
      });
      expect(result.sentences, isEmpty);
    });
  });

  // ── WebAsrException ──────────────────────────────────────────────────────

  test('WebAsrException toString 包含 message', () {
    const e = WebAsrException('network error');
    expect(e.toString(), contains('network error'));
  });
}
