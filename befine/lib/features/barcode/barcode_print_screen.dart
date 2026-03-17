import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class BarcodePrintScreen extends StatefulWidget {
  const BarcodePrintScreen({super.key});

  @override
  State<BarcodePrintScreen> createState() => _BarcodePrintScreenState();
}

class _BarcodePrintScreenState extends State<BarcodePrintScreen> {
  final Set<int> _selectedItems = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طباعة الباركودات'),
        actions: [
          if (_selectedItems.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('جارٍ طباعة ${_selectedItems.length} باركود...')),
                );
              },
              icon: const Icon(Icons.print, size: 18),
              label: Text('طباعة (${_selectedItems.length})'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن منتجات لطباعة باركوداتها...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_selectedItems.length} محدد', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: () => setState(() {
                    if (_selectedItems.length == 15) _selectedItems.clear();
                    else _selectedItems.addAll(List.generate(15, (i) => i));
                  }),
                  child: Text(_selectedItems.length == 15 ? 'إلغاء تحديد الكل' : 'تحديد الكل'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 15,
              itemBuilder: (ctx, i) {
                final isSelected = _selectedItems.contains(i);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : null,
                  child: ListTile(
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: (v) => setState(() {
                        if (v == true) _selectedItems.add(i);
                        else _selectedItems.remove(i);
                      }),
                      activeColor: AppColors.primary,
                    ),
                    title: Text('منتج ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('SKU: BF-${10000 + i}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    trailing: Container(
                      width: 80, height: 40,
                      decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(6)),
                      child: const Center(child: Icon(Icons.view_week, size: 30, color: Colors.white54)),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Colors.grey.shade800)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: 'Bluetooth',
                      decoration: InputDecoration(
                        labelText: 'الطابعة',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Bluetooth', child: Text('طابعة بلوتوث')),
                        DropdownMenuItem(value: 'WiFi', child: Text('طابعة Wi-Fi')),
                        DropdownMenuItem(value: 'PDF', child: Text('حفظ PDF')),
                      ],
                      onChanged: (_) {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _selectedItems.isEmpty ? null : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('جارٍ طباعة ${_selectedItems.length} باركود...'), backgroundColor: AppColors.success),
                        );
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('طباعة'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
