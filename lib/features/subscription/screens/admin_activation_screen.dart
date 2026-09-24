/// 管理员激活码生成页（内嵌于设置页的开发者选项）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

import '../../../router/app_router.dart';
import '../../../services/app_logger.dart';
import '../services/activation_code_service.dart';

class AdminActivationScreen extends ConsumerStatefulWidget {
  const AdminActivationScreen({super.key});

  @override
  ConsumerState<AdminActivationScreen> createState() =>
      _AdminActivationScreenState();
}

class _AdminActivationScreenState extends ConsumerState<AdminActivationScreen> {
  final _createdByCtrl = TextEditingController(text: 'admin');
  final _seatsCtrl = TextEditingController(text: '1');
  ActivationPeriod _selectedPeriod = ActivationPeriod.yearly;
  bool _generating = false;
  List<String>? _generatedCodes;
  String? _error;

  @override
  void dispose() {
    _createdByCtrl.dispose();
    _seatsCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final seats = int.tryParse(_seatsCtrl.text.trim()) ?? 1;
    if (seats < 1 || seats > 9999) {
      setState(() => _error = '座位数必须在 1~9999 之间');
      return;
    }
    setState(() {
      _generating = true;
      _generatedCodes = null;
      _error = null;
    });
    try {
      final service = ref.read(activationCodeServiceProvider);
      final codes = await service.generateCodes(
        accessToken: '',
        seats: seats,
        period: _selectedPeriod,
        createdBy: _createdByCtrl.text.trim(),
      );
      setState(() {
        _generating = false;
        _generatedCodes = codes;
      });
      AppLogger.log('AdminActivation', 'generated ${codes.length} codes');
    } catch (e) {
      setState(() {
        _generating = false;
        _error = e.toString();
      });
    }
  }

  void _copyAll() {
    if (_generatedCodes == null) return;
    final text = _generatedCodes!.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制到剪贴板')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('管理激活码'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.push(AppRoutes.activationStats),
            tooltip: '基础统计',
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () => context.push(AppRoutes.enhancedStats),
            tooltip: '高级统计',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('生成激活码', style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),

              TextField(
                controller: _createdByCtrl,
                decoration: const InputDecoration(
                  labelText: '创建人',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _seatsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '座位数（1~9999）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<ActivationPeriod>(
                initialValue: _selectedPeriod,
                decoration: const InputDecoration(
                  labelText: '套餐类型',
                  border: OutlineInputBorder(),
                ),
                items: ActivationPeriod.values.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text(_periodLabel(p)),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedPeriod = v!),
              ),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: _generating ? null : _generate,
                child: _generating
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
              ),
              const SizedBox(height: 12),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: cs.errorContainer,
                  child: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
                ),

              if (_generatedCodes != null && _generatedCodes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '已生成 ${_generatedCodes!.length} 个激活码',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _copyAll,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('复制'),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Share.share(_generatedCodes!.join('\n'), subject: '激活码');
                      },
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('分享'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(8),
                    itemCount: _generatedCodes!.length,
                    itemBuilder: (context, i) {
                      final code = _generatedCodes![i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          code,
                          style: const TextStyle(
                            fontSize: 14,
                            letterSpacing: 2,
                            fontFamily: 'monospace',
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('已复制 $code')),
                              );
                            }
                          },
                          child: const Text('复制'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _periodLabel(ActivationPeriod p) => switch (p) {
    ActivationPeriod.monthly => '月卡（1个月）',
    ActivationPeriod.quarterly => '季卡（3个月）',
    ActivationPeriod.halfYearly => '半年卡（6个月）',
    ActivationPeriod.yearly => '年卡（12个月）',
  };
}
