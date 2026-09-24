# Web 版构建修复指南

## 当前问题

编译错误：`'PlaybackState' isn't a type`

位置：`lib/database/providers_web.dart:982`

## 原因

`PlaybackState` 类定义在 `app_database.g.dart` 中，但 `providers_web.dart` 没有导入该类。

## 解决方案

### 方案 A：添加导入（推荐）

在 `lib/database/providers_web.dart` 文件顶部添加：

```dart
import 'app_database.g.dart' show PlaybackState;
```

**完整导入块应为**：
```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;
import 'app_database.dart' if (dart.library.html) 'drift_native_web_stub.dart';
import 'app_database.g.dart' show PlaybackState;  // ← 添加这行
import '../models/audio_item.dart' show AudioItem;
import '../models/collection.dart' show Collection;
import '../services/app_logger.dart';
import '../services/web_data/web_data_service.dart' show WebDataService;
```

### 方案 B：使用相对路径导入

如果方案 A 不起作用，尝试：

```dart
import '../../database/app_database.g.dart' show PlaybackState;
```

### 方案 C：降级到 Dart 3.9 兼容代码

如果无法升级 Flutter，需要修改 `providers_web.dart` 中的代码：

1. 将 `PlaybackState` 替换为自定义的简单数据结构
2. 或使用 `dynamic` 类型绕过类型检查

## 构建步骤

```bash
# 1. 确保使用 Flutter 3.47.2+
flutter --version  # 应显示 Dart 3.10+

# 2. 获取依赖
flutter pub get

# 3. 构建
flutter build web --release --dart-define=API_BASE_URL=http://38.55.146.160:3003

# 4. 部署
rsync -avz --delete build/web/ /www/workspace/Echo-Loop-landing/web/web/
sudo nginx -s reload

# 5. 验证
curl http://38.55.146.160:8100/web/version.json
```

## 验证清单

- [ ] `/web/` 返回 Flutter Web App
- [ ] `/web/main.dart.js` 可访问（10MB+）
- [ ] `/web/version.json` 返回 `{"version":"1.0.27"}`
- [ ] 浏览器能加载 Flutter 应用
- [ ] 登录功能正常
- [ ] 音频列表可加载
- [ ] 转录功能带认证

---

**最后更新**: 2026-08-28  
**相关 Commit**: b25d8513
