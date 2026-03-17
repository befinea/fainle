import 'package:flutter/material.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../widgets/organisms.dart';
import '../../widgets/molecules.dart';

class StorefrontScreen extends StatefulWidget {
  const StorefrontScreen({Key? key}) : super(key: key);

  @override
  State<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends State<StorefrontScreen> {
  int _cartItemCount = 0;

  void _addToCart() {
    setState(() {
      _cartItemCount++;
    });
    
    // Smooth micro-animation or snackbar feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item added to cart!'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Search Bar Area
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: SearchBarWidget(hintText: 'Search products by name...'),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.filter_list),
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: () {},
                        ),
                      )
                    ],
                  ),
                ),
                
                // Product Grid Area
                Expanded(
                  child: ResponsiveLayout(
                    mobile: _buildProductGrid(2),
                    tablet: _buildProductGrid(3),
                    desktop: _buildProductGrid(4),
                  ),
                ),
              ],
            ),
            
            // Hovering/Floating Cart Widget in Bottom Right
            Positioned(
              bottom: 32,
              right: 32,
              child: FloatingCartWidget(
                itemCount: _cartItemCount,
                onTap: () {
                  // Navigate to cart/checkout
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid(int crossAxisCount) {
    return GridView.builder(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 120), // Padding for cart
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        return ProductCard(
          title: 'Premium Ergonomic Item ${index + 1}',
          price: '\$${(99.99 + index * 10).toStringAsFixed(2)}',
          imageUrl: '', // Handled by inner placeholder
          onAddToCart: _addToCart,
        );
      },
    );
  }
}
