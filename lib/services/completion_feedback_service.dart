/// 完成反馈服务
///
/// 在学习子步骤完成时提供 Haptic 振动反馈。
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 完成反馈服务
///
/// 封装 HapticFeedback，供 [LearningProgressNotifier] 在
/// [completeCurrentSubStage] 完成后调用。
class CompletionFeedbackService {
  /// 播放完成反馈（Haptic 振动）
  ///
  /// [type] 控制反馈强度：
  /// - [CompletionType.success]：子步骤完成（中等振动）
  /// - [CompletionType.stageComplete]：阶段完成（强振动）
  Future<void> play(CompletionType type) async {
    switch (type) {
      case CompletionType.success:
        HapticFeedback.mediumImpact();

      case CompletionType.stageComplete:
        HapticFeedback.heavyImpact();

    }
  }
}

/// 完成反馈类型
enum CompletionType {
  /// 子步骤完成（中等反馈）
  success,

  /// 阶段完成（强反馈）
  stageComplete,
}

/// 完成反馈服务 Provider
final completionFeedbackServiceProvider =
    Provider<CompletionFeedbackService>((ref) => CompletionFeedbackService());
