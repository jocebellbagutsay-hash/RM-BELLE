import 'package:flutter/material.dart';

import '../routes.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/profile_header.dart';

/// Home menu serving as the central hub for the Activities Compilation.
/// Rebuilds when Provider settings change (profile name).
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 650;
            final padding = constraints.maxWidth >= 900 ? 32.0 : 16.0;

            final activityCards = AppRoutes.compilationActivities.map((activity) {
              return DashboardCard(
                activityNumber: activity.number,
                title: activity.title,
                subtitle: activity.subtitle,
                icon: activity.icon,
                tags: activity.tags,
                onTap: () => Navigator.pushNamed(context, activity.route),
              );
            }).toList();

            return SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ProfileHeader(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(
                        Icons.collections_bookmark_outlined,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Activities Compilation',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Compiled academic portfolio activities with dedicated navigation routes.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (wide)
                    LayoutBuilder(
                      builder: (context, cardConstraints) {
                        final columns = cardConstraints.maxWidth >= 950 ? 3 : 2;
                        const spacing = 12.0;
                        final cardWidth = (cardConstraints.maxWidth -
                                (columns - 1) * spacing) /
                            columns;

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: activityCards
                              .map(
                                (card) => SizedBox(
                                  width: cardWidth,
                                  child: card,
                                ),
                              )
                              .toList(),
                        );
                      },
                    )
                  else
                    Column(
                      children: activityCards
                          .map(
                            (card) => Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: card,
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
