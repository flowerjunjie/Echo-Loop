/// 邀请服务单测
library;

import 'package:dio/dio.dart';
import 'package:echo_loop/features/subscription/services/invite_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InviteException', () {
    test('toString 包含消息', () {
      const e = InviteException('test error');
      expect(e.toString(), contains('test error'));
    });
  });

  group('InviteRecord.fromJson', () {
    test('正常解析', () {
      final record = InviteRecord.fromJson({
        'inviteCode': 'ABC12345',
        'friendsSignedUp': 3,
        'monthsEarned': 30,
      });
      expect(record.inviteCode, 'ABC12345');
      expect(record.friendsSignedUp, 3);
      expect(record.monthsEarned, 30);
    });

    test('缺少字段时返回默认值', () {
      final record = InviteRecord.fromJson({});
      expect(record.inviteCode, '');
      expect(record.friendsSignedUp, 0);
      expect(record.monthsEarned, 0);
    });
  });

  group('InviteService.getInviteInfo', () {
    test('accessToken 为空时抛异常', () async {
      final service = InviteService.withDio(Dio());
      expect(
        () => service.getInviteInfo(accessToken: ''),
        throwsA(isA<InviteException>()),
      );
    });

    test('服务器返回 success=false 时抛异常', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    statusCode: 400,
                    data: {'success': false, 'error': '无效token'},
                    requestOptions: options,
                  ),
                ),
              );
            },
          ),
        );
      final service = InviteService.withDio(dio);
      await expectLater(
        service.getInviteInfo(accessToken: 'tok'),
        throwsA(isA<InviteException>()),
      );
    });
  });

  group('InviteService.attribution', () {
    test('正常调用不抛异常', () async {
      var called = false;
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              called = true;
              handler.next(options);
            },
          ),
        );
      final service = InviteService.withDio(dio);
      await service.attribution(inviteCode: 'ABC123', platform: 'ios');
      expect(called, isTrue);
    });
  });
}
