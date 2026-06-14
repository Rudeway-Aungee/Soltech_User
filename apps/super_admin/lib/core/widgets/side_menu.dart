import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';

class SideMenuItem {
  const SideMenuItem({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;
}

class SideMenu extends StatelessWidget {
  const SideMenu({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<SideMenuItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFFEAF7EF),
                  child: Icon(Icons.local_taxi, color: AppColors.primary),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Soltech Admin',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final active = index == selectedIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    selected: active,
                    selectedTileColor: AppColors.primary.withOpacity(0.10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: Icon(
                      item.icon,
                      color: active ? AppColors.primary : AppColors.muted,
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                    onTap: () => onSelected(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}