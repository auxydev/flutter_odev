import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/expense_category.dart';
import '../../services/report_service.dart';
import '../../state/auth_controller.dart';
import '../../state/receipt_controller.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../utils/text_utils.dart';
import '../../widgets/common.dart';
import '../receipts/add_receipt_flow.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  /// 1: Raporlar, 2: Geçmiş Fişler
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final receipts = context.watch<ReceiptController>().receipts;
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = ReportData.build(receipts, rangeFor(ReportPeriod.daily, now), ReportPeriod.daily);
    final week = ReportData.build(receipts, rangeFor(ReportPeriod.weekly, now), ReportPeriod.weekly);
    final month = ReportData.build(receipts, rangeFor(ReportPeriod.monthly, now), ReportPeriod.monthly);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          // --- Üst başlık: "Merhaba kullanıcı!" + sağda "+" butonu
          Row(
            children: [
              PopupMenuButton<String>(
                tooltip: 'Hesap',
                onSelected: (value) async {
                  if (value == 'logout') await context.read<AuthController>().logout();
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Text(user.email),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.logout),
                      title: Text('Çıkış yap'),
                    ),
                  ),
                ],
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(gradient: brandGradient, shape: BoxShape.circle),
                  child: Text(
                    trUpper(user.username.substring(0, 1)),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merhaba ${user.username}!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 21),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatDate(now)}, ${formatWeekday(now)}',
                      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              _AddButton(onPressed: () => startAddReceipt(context)),
            ],
          ),
          const SizedBox(height: 24),

          // --- Bu ayın özeti
          _MonthSummaryCard(
            monthTotal: month.total,
            monthCount: month.count,
            todayTotal: today.total,
            weekTotal: week.total,
            onTap: () => onNavigate(1),
          ),

          // --- Bu ay kategoriler
          if (month.byCategory.isNotEmpty) ...[
            const SectionHeader(title: 'Bu ay nereye harcadın?'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final share in month.byCategory.take(4))
                      _CategoryBar(share: share, monthTotal: month.total),
                  ],
                ),
              ),
            ),
          ],

          // --- Son fişler
          SectionHeader(
            title: 'Son fişler',
            action: receipts.isEmpty
                ? null
                : TextButton(onPressed: () => onNavigate(2), child: const Text('Tümünü gör')),
          ),
          if (receipts.isEmpty)
            Card(
              child: EmptyState(
                icon: Icons.document_scanner_outlined,
                title: 'Henüz fiş eklemedin',
                message: 'Sağ üstteki + butonuna basarak ilk fişini tara.',
                action: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                  ),
                  onPressed: () => startAddReceipt(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Fiş ekle'),
                ),
              ),
            )
          else
            CardList(children: [for (final r in receipts.take(5)) ReceiptTile(receipt: r)]),
        ],
      ),
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({
    required this.monthTotal,
    required this.monthCount,
    required this.todayTotal,
    required this.weekTotal,
    required this.onTap,
  });

  final double monthTotal;
  final int monthCount;
  final double todayTotal;
  final double weekTotal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const onCard = Colors.white;
    final now = DateTime.now();
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: brandColor.withValues(alpha: isDark(context) ? 0.15 : 0.3),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            // Açık ve koyu temada aynı kalan marka gradyanı (beyaz yazı okunaklı kalsın).
            decoration: const BoxDecoration(gradient: brandGradient),
            child: Stack(
              children: [
                Positioned(right: -50, top: -60, child: _glow(190, 0.09)),
                Positioned(right: 60, bottom: -90, child: _glow(160, 0.06)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${formatMonthYear(now)} harcaman',
                            style: TextStyle(
                              color: onCard.withValues(alpha: 0.82),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: onCard.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.receipt_long_rounded, size: 14, color: onCard),
                                const SizedBox(width: 5),
                                Text(
                                  '$monthCount fiş',
                                  style: const TextStyle(
                                    color: onCard,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatMoney(monthTotal),
                          style: const TextStyle(
                            color: onCard,
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _MiniStat(label: 'Bugün', value: todayTotal)),
                            Container(width: 1, height: 30, color: onCard.withValues(alpha: 0.2)),
                            const SizedBox(width: 14),
                            Expanded(child: _MiniStat(label: 'Bu hafta', value: weekTotal)),
                            Icon(Icons.arrow_forward_rounded,
                                size: 20, color: onCard.withValues(alpha: 0.85)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glow(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Fiş ekle',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.add_rounded, size: 30, color: scheme.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatMoney(value),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.share, required this.monthTotal});

  final AmountShare share;
  final double monthTotal;

  @override
  Widget build(BuildContext context) {
    final category = ExpenseCategory.byId(share.key);
    final ratio = monthTotal <= 0 ? 0.0 : (share.amount / monthTotal).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          CategoryAvatar(categoryId: share.key, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(category.label,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text(formatMoney(share.amount),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    color: category.color,
                    backgroundColor: category.color.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
