import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';
import 'responsive_card.dart';

class ResponsiveDashboard extends StatelessWidget {
  final String title;
  final List<DashboardItem> items;

  const ResponsiveDashboard({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = ResponsiveHelper.isMobile(screenWidth);
        
        return Padding(
          padding: EdgeInsets.all(ResponsiveHelper.getContentPadding(screenWidth)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              ResponsiveText(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 24 : 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: ResponsiveHelper.getContentPadding(screenWidth)),
              
              // Grid of items
              Expanded(
                child: _buildItemGrid(screenWidth),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemGrid(double screenWidth) {
    final columns = ResponsiveHelper.getGridColumns(screenWidth);
    final itemHeight = ResponsiveHelper.isMobile(screenWidth) ? 120.0 : 140.0;
    
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: screenWidth > 800 ? 2.5 : 2.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ResponsiveCard(
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          item.icon,
                          color: item.color,
                          size: ResponsiveHelper.isMobile(screenWidth) ? 20 : 24,
                        ),
                      ),
                      const Spacer(),
                      if (item.badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ResponsiveText(
                    item.title,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.isMobile(screenWidth) ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ResponsiveText(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.isMobile(screenWidth) ? 12 : 14,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DashboardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
  });
} 