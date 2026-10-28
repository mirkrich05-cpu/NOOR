import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../data/zakat_repository.dart';

class ZakatScreen extends ConsumerStatefulWidget {
  const ZakatScreen({super.key});

  @override
  ConsumerState<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends ConsumerState<ZakatScreen> {
  String _currency = 'ILS'; // Supports ILS, USD, EUR, JOD
  bool _useGoldNisab = true; // Gold 85g vs Silver 595g

  final _cashCtrl = TextEditingController(text: '0');
  final _savingsCtrl = TextEditingController(text: '0');
  final _goldGramsCtrl = TextEditingController(text: '0');
  final _silverGramsCtrl = TextEditingController(text: '0');
  final _investmentsCtrl = TextEditingController(text: '0');
  final _businessGoodsCtrl = TextEditingController(text: '0');
  final _debtsCtrl = TextEditingController(text: '0');

  final _goldPriceCtrl = TextEditingController(text: '315.0');
  final _silverPriceCtrl = TextEditingController(text: '3.80');

  // Zakat al-Fitr inputs
  int _familyMembers = 4;
  final _fitrPerPersonCtrl = TextEditingController(text: '20.0');

  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _refreshLivePrices();
    _loadHistory();
  }

  Future<void> _refreshLivePrices() async {
    final prices = await ref
        .read(zakatRepositoryProvider)
        .fetchLiveMetalPrices(_currency);
    if (mounted) {
      setState(() {
        _goldPriceCtrl.text = prices.goldGramPrice.toStringAsFixed(2);
        _silverPriceCtrl.text = prices.silverGramPrice.toStringAsFixed(2);
      });
    }
  }

  Future<void> _loadHistory() async {
    final rows = await ref.read(zakatRepositoryProvider).getSavedRecords();
    if (mounted) setState(() => _history = rows);
  }

  double _val(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    final goldPrice = _val(_goldPriceCtrl);
    final silverPrice = _val(_silverPriceCtrl);

    final cash = _val(_cashCtrl);
    final savings = _val(_savingsCtrl);
    final goldValue = _val(_goldGramsCtrl) * goldPrice;
    final silverValue = _val(_silverGramsCtrl) * silverPrice;
    final investments = _val(_investmentsCtrl);
    final businessGoods = _val(_businessGoodsCtrl);
    final debts = _val(_debtsCtrl);

    final grossAssets =
        cash + savings + goldValue + silverValue + investments + businessGoods;
    final netZakatableWealth =
        (grossAssets - debts).clamp(0.0, double.infinity);

    final goldNisab = 85.0 * goldPrice;
    final silverNisab = 595.0 * silverPrice;
    final activeNisab = _useGoldNisab ? goldNisab : silverNisab;

    final isAboveNisab = netZakatableWealth >= activeNisab;
    final zakatDue = isAboveNisab ? netZakatableWealth * 0.025 : 0.0;
    final fitrTotal = _familyMembers * _val(_fitrPerPersonCtrl);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tr('zakat_calculator')),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Fetch Live Gold & Silver Prices',
            onPressed: _refreshLivePrices,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Currency & Nisab Standard Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _currency,
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                            prefixIcon: Icon(Icons.currency_exchange),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'ILS',
                              child: Text('ILS (₪) - Shekel'),
                            ),
                            DropdownMenuItem(
                              value: 'JOD',
                              child: Text('JOD (د.أ) - Jordanian Dinar'),
                            ),
                            DropdownMenuItem(
                              value: 'USD',
                              child: Text('USD (\$) - US Dollar'),
                            ),
                            DropdownMenuItem(
                              value: 'EUR',
                              child: Text('EUR (€) - Euro'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _currency = v);
                              _refreshLivePrices();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _goldPriceCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Gold / gram ($_currency)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _silverPriceCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Silver / gram ($_currency)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _useGoldNisab
                          ? 'Nisab Standard: Gold (85g = ${goldNisab.toStringAsFixed(0)} $_currency)'
                          : 'Nisab Standard: Silver (595g = ${silverNisab.toStringAsFixed(0)} $_currency)',
                    ),
                    value: _useGoldNisab,
                    onChanged: (v) => setState(() => _useGoldNisab = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Wealth Inputs Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Zakatable Assets & Liabilities',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildNumberField('Cash on Hand ($_currency)', _cashCtrl),
                  _buildNumberField('Bank Savings ($_currency)', _savingsCtrl),
                  _buildNumberField('Gold Weight (grams)', _goldGramsCtrl),
                  _buildNumberField('Silver Weight (grams)', _silverGramsCtrl),
                  _buildNumberField(
                      'Stocks / Investments ($_currency)', _investmentsCtrl),
                  _buildNumberField('Business Inventory / Goods ($_currency)',
                      _businessGoodsCtrl),
                  _buildNumberField(
                      'Debts Owed (Deductible) ($_currency)', _debtsCtrl),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Zakat Summary Breakdown Card
          Card(
            color: AppColors.primaryGreen,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    loc.tr('zakat_due'),
                    style: const TextStyle(
                      color: AppColors.accentGold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${zakatDue.toStringAsFixed(2)} $_currency',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  _summaryRow('Gross Assets:',
                      '${grossAssets.toStringAsFixed(2)} $_currency'),
                  _summaryRow('Deductible Debts:',
                      '- ${debts.toStringAsFixed(2)} $_currency'),
                  _summaryRow('Net Zakatable Wealth:',
                      '${netZakatableWealth.toStringAsFixed(2)} $_currency'),
                  _summaryRow('Active Nisab Threshold:',
                      '${activeNisab.toStringAsFixed(2)} $_currency'),
                  _summaryRow(
                    'Status:',
                    isAboveNisab
                        ? 'Above Nisab (2.5% Zakat Payable)'
                        : 'Below Nisab (No Zakat Due)',
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGold,
                      foregroundColor: AppColors.deepEmerald,
                    ),
                    onPressed: () async {
                      final hNow = HijriCalendar.now();
                      final hStr =
                          '${hNow.hDay} ${hNow.longMonthName} ${hNow.hYear} AH';
                      await ref
                          .read(zakatRepositoryProvider)
                          .saveYearlyZakatRecord(
                            hijriDate: hStr,
                            currency: _currency,
                            netWealth: netZakatableWealth,
                            nisabUsed: activeNisab,
                            zakatDue: zakatDue,
                          );
                      await NotificationService.instance.showInstantNotification(
                        id: 7700,
                        title: 'Zakat Record Saved ($hStr)',
                        body:
                            'Hijri anniversary reminder set for next year (${hNow.hYear + 1} AH).',
                      );
                      _loadHistory();
                    },
                    icon: const Icon(Icons.save),
                    label: const Text(
                      'Save Yearly Record & Set Hijri Anniversary Reminder',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Zakat al-Fitr Calculator Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Zakat al-Fitr Calculator (زكاة الفطر)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Household Members:'),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          if (_familyMembers > 1) {
                            setState(() => _familyMembers--);
                          }
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$_familyMembers',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _familyMembers++),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  _buildNumberField(
                    'Fitr Rate per Person (1 Sa' ~ 2.5-3kg staple food in $_currency)',
                    _fitrPerPersonCtrl,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Zakat al-Fitr Due: ${fitrTotal.toStringAsFixed(2)} $_currency',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_history.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Saved Yearly Zakat Records',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._history.map(
              (r) => Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.history_edu,
                    color: AppColors.primaryGreen,
                  ),
                  title: Text(
                    '${(r['zakat_due'] as num).toStringAsFixed(2)} ${r['currency']} (Net: ${(r['net_wealth'] as num).toStringAsFixed(0)})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Hijri Date: ${r['hijri_date']}'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
