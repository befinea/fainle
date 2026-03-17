import 'package:flutter/material.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../widgets/atoms.dart';
import '../../widgets/molecules.dart';
import '../../widgets/organisms.dart';
import '../../../core/theme/app_colors.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(),
        tablet: _buildDesktopLayout(), // For tablet we can use desktop layout or a modified one
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      drawer: AdminSidebar(
        selectedIndex: _selectedIndex,
        onItemSelected: (i) {
          setState(() => _selectedIndex = i);
          Navigator.pop(context); // Close drawer
        },
      ),
      body: _buildDashboardContent(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        AdminSidebar(
          selectedIndex: _selectedIndex,
          onItemSelected: (i) => setState(() => _selectedIndex = i),
        ),
        Expanded(
          child: _buildDashboardContent(),
        ),
      ],
    );
  }

  Widget _buildDashboardContent() {
    return Container(
      color: AppColors.backgroundLight,
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppText(
                'Dashboard Overview',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 300, child: SearchBarWidget()),
            ],
          ),
          const SizedBox(height: 32),
          
          // Stats Row
          Row(
            children: [
              const Expanded(child: StatCardMolecule(title: 'Total Sales', value: '\$24,500', icon: Icons.attach_money, iconColor: AppColors.primary)),
              const SizedBox(width: 16),
              const Expanded(child: StatCardMolecule(title: 'Orders', value: '1,245', icon: Icons.shopping_cart, iconColor: AppColors.secondary)),
              const SizedBox(width: 16),
              const Expanded(child: StatCardMolecule(title: 'Customers', value: '842', icon: Icons.people, iconColor: AppColors.error)),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Data Table Area
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText('Recent Orders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: DataTable(
                            headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondaryLight),
                            columns: const [
                              DataColumn(label: Text('Order ID')),
                              DataColumn(label: Text('Customer')),
                              DataColumn(label: Text('Date'), onSort: null),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Amount')),
                            ],
                            rows: [
                              _buildRow('#ORD-001', 'John Doe', '2023-10-24', 'Delivered', '\$120.00'),
                              _buildRow('#ORD-002', 'Jane Smith', '2023-10-24', 'Processing', '\$85.50'),
                              _buildRow('#ORD-003', 'Mark Johnson', '2023-10-23', 'Shipped', '\$210.00'),
                              _buildRow('#ORD-004', 'Emily Davis', '2023-10-22', 'Delivered', '\$45.00'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(String id, String customer, String date, String status, String amount) {
    Color statusColor = status == 'Delivered' ? AppColors.success : (status == 'Processing' ? AppColors.error : AppColors.primary);
    
    return DataRow(
      cells: [
        DataCell(Text(id, style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(Text(customer)),
        DataCell(Text(date)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        DataCell(Text(amount, style: const TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }
}
