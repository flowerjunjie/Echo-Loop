/// 邀请裂变状态 Provider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../services/invite_service.dart';

/// 邀请信息异步状态
enum InviteStateStatus { loading, success, error }

/// 邀请信息异步数据
class InviteState {
  final InviteStateStatus status;
  final String inviteCode;
  final int friendsSignedUp;
  final int monthsEarned;
  final String? errorMessage;

  const InviteState({
    required this.status,
    this.inviteCode = '',
    this.friendsSignedUp = 0,
    this.monthsEarned = 0,
    this.errorMessage,
  });

  const InviteState.loading()
      : status = InviteStateStatus.loading,
        inviteCode = '',
        friendsSignedUp = 0,
        monthsEarned = 0,
        errorMessage = null;

  const InviteState.error([this.errorMessage = ''])
      : status = InviteStateStatus.error,
        inviteCode = '',
        friendsSignedUp = 0,
        monthsEarned = 0;

  bool get isLoading => status == InviteStateStatus.loading;
  bool get hasData => status == InviteStateStatus.success;
}

/// 邀请信息 Provider
///
/// 自动从 [authSessionProvider] 读取 accessToken，
/// 调用 [inviteServiceProvider] 获取邀请码和统计数据。
/// 用户登出后自动重置为 [InviteState.loading]。
final inviteStateProvider = StateNotifierProvider<InviteNotifier, InviteState>(
  (ref) => InviteNotifier(ref),
);

class InviteNotifier extends StateNotifier<InviteState> {
  InviteNotifier(this._ref) : super(const InviteState.loading()) {
    _ref.listen<AuthResponse?>(
      authSessionProvider,
      (_, next) {
        // 身份变化时重新加载
        if (next?.accessToken != null) {
          load();
        } else {
          state = const InviteState.loading();
        }
      },
    );
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    final identity = _ref.read(authSessionProvider);
    if (identity == null || identity.accessToken == null) {
      state = const InviteState.error('请先登录');
      return;
    }
    state = const InviteState.loading();
    try {
      final service = _ref.read(inviteServiceProvider);
      final record = await service.getInviteInfo(accessToken: identity.accessToken!);
      state = InviteState(
        status: InviteStateStatus.success,
        inviteCode: record.inviteCode,
        friendsSignedUp: record.friendsSignedUp,
        monthsEarned: record.monthsEarned,
      );
    } on InviteException catch (e) {
      state = InviteState.error(e.message);
    } catch (e) {
      state = const InviteState.error('inviteErrorNetwork');
    }
  }
}
