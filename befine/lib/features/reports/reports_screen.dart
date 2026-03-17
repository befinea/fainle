import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../ui/widgets/animated_glass_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _supabase = Supabase.instance.client;
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
    if (mounted) setState(() => _companyId = profile['company_id'] as String);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.background,
            theme.colorScheme.background.withOpacity(0.9),
            theme.colorScheme.primary.withOpacity(0.05),
          ],
        ),
      ),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text('التقارير والتحليلات', style: theme.textTheme.titleLarge),
            bottom: TabBar(
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppColors.primary.withOpacity(0.1),
              ),
              tabs: const [
                Tab(text: 'المبيعات'),
                Tab(text: 'المخزون'),
                Tab(text: 'الأرباح'),
              ],
            ),
          ),
          body: _companyId == null
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    _SalesReport(companyId: _companyId!),
                    _StockReport(companyId: _companyId!),
                    _ProfitReport(companyId: _companyId!),
                  ],
                ),
        ),
      ),
    );
  }
}

// =========================== SALES TAB ===========================
class _SalesReport extends StatefulWidget {
  final String companyId;
  const _SalesReport({required this.companyId});

  @override
  State<_SalesReport> createState() => _SalesReportState();
}

class _SalesReportState extends State<_SalesReport> {
  final _supabase = Supabase.instance.client;
  double _todaySales = 0;
  double _weekSales = 0;
  double _monthSales = 0;
  int _orderCount = 0;
  List<Map<String, dynamic>> _topProducts = [];
  List<double> _weeklyData = [0, 0, 0, 0, 0, 0, 0];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final now = DateTime.now().toUtc();
      final todayStart = DateTime.utc(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime.utc(now.year, now.month, 1);

      final allSales = await _supabase
          .from('transactions')
          .select('total_amount, created_at')
          .eq('company_id', widget.companyId)
          .eq('type', 'sale')
          .order('created_at', ascending: false);

      double today = 0, week = 0, month = 0;
      int count = (allSales as List).length;
      List<double> daily = [0, 0, 0, 0, 0, 0, 0];

      for (final s in allSales) {
        final amount = (s['total_amount'] as num?)?.toDouble() ?? 0;
        final dt = DateTime.parse(s['created_at'] as String);
        if (dt.isAfter(todayStart)) today += amount;
        if (dt.isAfter(weekStart)) {
          week += amount;
          final dayIdx = dt.weekday - 1; // 0=Mon, 6=Sun
          if (dayIdx >= 0 && dayIdx < 7) daily[dayIdx] += amount;
        }
        if (dt.isAfter(monthStart)) month += amount;
      }

      // Top products by sales
      List<Map<String, dynamic>> topProducts = [];
      try {
        final items = await _supabase
            .from('transaction_items')
            .select('quantity, unit_price, product_id, products(name), transactions!inner(company_id, type)')
            .eq('transactions.company_id', widget.companyId)
            .eq('transactions.type', 'sale');

        final Map<String, Map<String, dynamic>> productMap = {};
        for (final item in items) {
          final pid = item['product_id'] as String;
          final qty = (item['quantity'] as num?)?.toInt() ?? 0;
          final price = (item['unit_price'] as num?)?.toDouble() ?? 0;
          final name = item['products']?['name'] ?? 'منتج';
          if (!productMap.containsKey(pid)) {
            productMap[pid] = {'name': name, 'qty': 0, 'revenue': 0.0};
          }
          productMap[pid]!['qty'] = (productMap[pid]!['qty'] as int) + qty;
          productMap[pid]!['revenue'] = (productMap[pid]!['revenue'] as double) + (qty * price);
        }
        topProducts = productMap.values.toList()
          ..sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));
        if (topProducts.length > 5) topProducts = topProducts.sublist(0, 5);
      } catch (_) {}

      // Normalize weekly chart
      final maxDaily = daily.reduce((a, b) => a > b ? a : b);

      if (mounted) {
        setState(() {
          _todaySales = today;
          _weekSales = week;
          _monthSales = month;
          _orderCount = count;
          _topProducts = topProducts;
          _weeklyData = maxDaily > 0 ? daily.map((d) => (d / maxDaily) * 20).toList() : daily;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Sales report error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(children: [
            Row(children: [
              Expanded(child: _ReportCard(title: 'اليوم', value: '${_todaySales.toStringAsFixed(0)} د', icon: Icons.today_rounded, color: AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _ReportCard(title: 'هذا الأسبوع', value: '${_weekSales.toStringAsFixed(0)} د', icon: Icons.calendar_view_week, color: AppColors.secondary)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _ReportCard(title: 'هذا الشهر', value: '${_monthSales.toStringAsFixed(0)} د', icon: Icons.calendar_month, color: Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _ReportCard(title: 'إجمالي الطلبات', value: '$_orderCount', icon: Icons.shopping_bag_rounded, color: AppColors.success)),
            ]),
          ]),
          const SizedBox(height: 24),
          AnimatedGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('أداء المبيعات الأسبوعي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 32),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 20,
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              const days = ['إث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'];
                              if (val.toInt() >= 0 && val.toInt() < days.length) {
                                return Text(days[val.toInt()], style: const TextStyle(fontSize: 10, color: Colors.grey));
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(7, (i) => BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: _weeklyData[i],
                            color: AppColors.primary,
                            width: 16,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            backDrawRodData: BackgroundBarChartRodData(show: true, toY: 20, color: AppColors.primary.withOpacity(0.05)),
                          ),
                        ],
                      )),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('أكثر المنتجات مبيعاً', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_topProducts.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('لا توجد بيانات بعد', style: TextStyle(color: Colors.grey.shade500))))
          else
            ...List.generate(_topProducts.length, (i) {
              final p = _topProducts[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AnimatedGlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${p['qty']} عملية بيع', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ])),
                    Text('${(p['revenue'] as double).toStringAsFixed(0)} د', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success)),
                  ]),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// =========================== STOCK TAB ===========================
class _StockReport extends StatefulWidget {
  final String companyId;
  const _StockReport({required this.companyId});

  @override
  State<_StockReport> createState() => _StockReportState();
}

class _StockReportState extends State<_StockReport> {
  final _supabase = Supabase.instance.client;
  int _totalProducts = 0;
  int _lowStockCount = 0;
  List<Map<String, dynamic>> _lowStockItems = [];
  List<PieChartSectionData> _pieSections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      // Product count
      final products = await _supabase.from('products').select('id, category_id, categories(name)').eq('company_id', widget.companyId);
      final totalProducts = (products as List).length;

      // Category distribution for pie chart
      final Map<String, int> categoryCount = {};
      for (final p in products) {
        final catName = p['categories']?['name'] as String? ?? 'بدون تصنيف';
        categoryCount[catName] = (categoryCount[catName] ?? 0) + 1;
      }
      final colors = [AppColors.primary, AppColors.secondary, AppColors.success, Colors.orange, Colors.purple, Colors.teal, Colors.pink];
      int ci = 0;
      final pieSections = categoryCount.entries.map((e) {
        final color = colors[ci % colors.length];
        ci++;
        return PieChartSectionData(
          color: color,
          value: e.value.toDouble(),
          title: e.key,
          radius: 50,
          titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        );
      }).toList();

      // Low stock items
      List<Map<String, dynamic>> lowItems = [];
      int lowCount = 0;
      try {
        final stockData = await _supabase
            .from('stock_levels')
            .select('quantity, min_threshold, products(name), locations(name, company_id)')
            .limit(200);

        for (final row in stockData) {
          final q = (row['quantity'] as num?)?.toInt() ?? 0;
          final t = (row['min_threshold'] as num?)?.toInt() ?? 5;
          final locCompany = row['locations']?['company_id'] as String? ?? '';
          if (q <= t && locCompany == widget.companyId) {
            lowCount++;
            lowItems.add({
              'name': row['products']?['name'] ?? 'منتج',
              'location': row['locations']?['name'] ?? '',
              'quantity': q,
              'threshold': t,
            });
          }
        }
        lowItems.sort((a, b) => (a['quantity'] as int).compareTo(b['quantity'] as int));
        if (lowItems.length > 5) lowItems = lowItems.sublist(0, 5);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _totalProducts = totalProducts;
          _lowStockCount = lowCount;
          _lowStockItems = lowItems;
          _pieSections = pieSections;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Stock report error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: _ReportCard(title: 'إجمالي المنتجات', value: '$_totalProducts', icon: Icons.inventory_2_rounded, color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _ReportCard(title: 'مخزون منخفض', value: '$_lowStockCount', icon: Icons.warning_amber_rounded, color: Colors.orange)),
          ]),
          const SizedBox(height: 24),
          if (_pieSections.isEmpty)
            AnimatedGlassCard(
              padding: const EdgeInsets.all(20),
              child: Center(child: Text('لا توجد منتجات بعد', style: TextStyle(color: Colors.grey.shade500))),
            )
          else
            AnimatedGlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const Text('توزيع المنتجات حسب التصنيف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 160,
                  child: PieChart(PieChartData(sectionsSpace: 4, centerSpaceRadius: 40, sections: _pieSections)),
                ),
              ]),
            ),
          const SizedBox(height: 24),
          const Text('منتجات بمخزون منخفض', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_lowStockItems.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('لا توجد منتجات بمخزون منخفض', style: TextStyle(color: Colors.grey.shade500))))
          else
            ...List.generate(_lowStockItems.length, (i) {
              final item = _lowStockItems[i];
              final isCritical = (item['quantity'] as int) <= 2;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AnimatedGlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: (isCritical ? AppColors.error : Colors.orange).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.warning_amber, color: isCritical ? AppColors.error : Colors.orange, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(item['location'] as String, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: (isCritical ? AppColors.error : Colors.orange).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Text('${item['quantity']} متبق', style: TextStyle(fontWeight: FontWeight.bold, color: isCritical ? AppColors.error : Colors.orange)),
                    ),
                  ]),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// =========================== PROFIT TAB ===========================
class _ProfitReport extends StatefulWidget {
  final String companyId;
  const _ProfitReport({required this.companyId});

  @override
  State<_ProfitReport> createState() => _ProfitReportState();
}

class _ProfitReportState extends State<_ProfitReport> {
  final _supabase = Supabase.instance.client;
  double _totalRevenue = 0;
  double _totalProfit = 0;
  List<FlSpot> _revenueSpots = [];
  List<FlSpot> _profitSpots = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      // Revenue from sales
      final sales = await _supabase
          .from('transactions')
          .select('total_amount, created_at')
          .eq('company_id', widget.companyId)
          .eq('type', 'sale')
          .order('created_at', ascending: false);

      double revenue = 0;
      for (final s in sales) {
        revenue += (s['total_amount'] as num?)?.toDouble() ?? 0;
      }

      // Profit from transaction_items (sale_price - purchase_price) * qty
      double profit = 0;
      try {
        final items = await _supabase
            .from('transaction_items')
            .select('quantity, unit_price, product_id, products(purchase_price), transactions!inner(company_id, type)')
            .eq('transactions.company_id', widget.companyId)
            .eq('transactions.type', 'sale');

        for (final item in items) {
          final qty = (item['quantity'] as num?)?.toInt() ?? 0;
          final salePrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
          final purchasePrice = (item['products']?['purchase_price'] as num?)?.toDouble() ?? 0;
          profit += (salePrice - purchasePrice) * qty;
        }
      } catch (_) {}

      // Weekly chart data (last 7 days)
      final now = DateTime.now().toUtc();
      List<double> dailyRevenue = List.filled(7, 0);

      for (final s in sales) {
        final dt = DateTime.parse(s['created_at'] as String);
        final diff = now.difference(dt).inDays;
        if (diff < 7) {
          final idx = 6 - diff;
          dailyRevenue[idx] += (s['total_amount'] as num?)?.toDouble() ?? 0;
        }
      }

      // Normalize for chart
      final maxRev = dailyRevenue.reduce((a, b) => a > b ? a : b);
      final factor = maxRev > 0 ? 8.0 / maxRev : 1.0;

      if (mounted) {
        setState(() {
          _totalRevenue = revenue;
          _totalProfit = profit;
          _revenueSpots = List.generate(7, (i) => FlSpot(i.toDouble(), dailyRevenue[i] * factor));
          _profitSpots = List.generate(7, (i) => FlSpot(i.toDouble(), dailyRevenue[i] * factor * (revenue > 0 ? profit / revenue : 0)));
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Profit report error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final costPct = _totalRevenue > 0 ? (_totalRevenue - _totalProfit) / _totalRevenue : 0.0;
    final profitPct = _totalRevenue > 0 ? _totalProfit / _totalRevenue : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: _ReportCard(title: 'الإيرادات', value: '${_totalRevenue.toStringAsFixed(0)} د', icon: Icons.trending_up, color: AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _ReportCard(title: 'إجمالي الربح', value: '${_totalProfit.toStringAsFixed(0)} د', icon: Icons.attach_money, color: AppColors.primary)),
          ]),
          const SizedBox(height: 24),
          AnimatedGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تحليل الإيرادات والربح', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 24),
                SizedBox(
                  height: 180,
                  child: LineChart(LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _revenueSpots.isEmpty ? [const FlSpot(0, 0)] : _revenueSpots,
                        isCurved: true, color: AppColors.success, barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: AppColors.success.withOpacity(0.1)),
                      ),
                      LineChartBarData(
                        spots: _profitSpots.isEmpty ? [const FlSpot(0, 0)] : _profitSpots,
                        isCurved: true, color: AppColors.primary, barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.1)),
                      ),
                    ],
                  )),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _buildLegendItem('الإيرادات', AppColors.success),
                  const SizedBox(width: 24),
                  _buildLegendItem('الربح', AppColors.primary),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AnimatedGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تفاصيل النسبة المئوية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                _buildBreakdownRow('تكلفة البضاعة', costPct.clamp(0, 1), Colors.orange),
                const SizedBox(height: 12),
                _buildBreakdownRow('صافي الربح', profitPct.clamp(0, 1), AppColors.success),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ]);
  }

  Widget _buildBreakdownRow(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text('${(value * 100).toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// =========================== SHARED WIDGETS ===========================
class _ReportCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _ReportCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedGlassCard(
      padding: const EdgeInsets.all(14),
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
