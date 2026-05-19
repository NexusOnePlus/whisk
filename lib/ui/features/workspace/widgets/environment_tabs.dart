import 'package:flutter/material.dart';
import 'package:whisk/domain/models/environment_kind.dart';

class EnvironmentTabs extends StatelessWidget {
  const EnvironmentTabs({
    super.key,
    required this.environments,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<EnvironmentKind> environments;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: environments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final environment = environments[index];
          final selected = selectedIndex == index;

          return ChoiceChip(
            selected: selected,
            label: Text(environment.name),
            avatar: Icon(environment.icon, size: 18),
            onSelected: (_) => onSelected(index),
          );
        },
      ),
    );
  }
}
