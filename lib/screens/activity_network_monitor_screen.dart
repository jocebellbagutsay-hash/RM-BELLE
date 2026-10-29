import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/network_request_item.dart';
import '../providers/network_monitor_provider.dart';

/// Activity 3: Network Monitor Screen.
/// Demonstrates connectivity_plus real-time stream listening, active interface dashboard,
/// resilient request queueing during handover/offline drops, and graceful auto-recovery.
class ActivityNetworkMonitorScreen extends StatelessWidget {
  const ActivityNetworkMonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final monitor = context.watch<NetworkMonitorProvider>();

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Clear completed requests',
            icon: const Icon(Icons.cleaning_services_outlined),
            onPressed: monitor.completedCount > 0
                ? () => monitor.clearCompleted()
                : null,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 840;
            final padding = constraints.maxWidth >= 600 ? 24.0 : 16.0;

            return SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Real-time Active Network Interface Dashboard Card
                  _buildActiveInterfaceCard(context, monitor),
                  const SizedBox(height: 16),

                  // Simulation & Handover Control Bar
                  _buildSimulationControls(context, monitor),
                  const SizedBox(height: 20),

                  // Action Buttons for Triggering Long-Running Requests
                  _buildRequestActionSection(context, monitor),
                  const SizedBox(height: 20),

                  // Layout split for wide vs compact screens
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildQueueSection(context, monitor),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _buildEventLogSection(context, monitor),
                        ),
                      ],
                    )
                  else ...[
                    _buildQueueSection(context, monitor),
                    const SizedBox(height: 20),
                    _buildEventLogSection(context, monitor),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }


  Widget _buildActiveInterfaceCard(
    BuildContext context,
    NetworkMonitorProvider monitor,
  ) {
    final type = monitor.currentInterface;
    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusSubtitle;

    switch (type) {
      case NetworkInterfaceType.wifi:
        statusColor = Colors.green.shade600;
        statusIcon = Icons.wifi_rounded;
        statusTitle = 'Connected to Wi-Fi';
        statusSubtitle =
            'High-bandwidth local wireless link active. Ready for streaming & batch transfers.';
        break;
      case NetworkInterfaceType.cellular:
        statusColor = Colors.blue.shade600;
        statusIcon = Icons.cell_tower_rounded;
        statusTitle = 'Connected to Cellular (Mobile Data)';
        statusSubtitle =
            'Cellular carrier interface active. Metered network requests supported.';
        break;
      case NetworkInterfaceType.other:
        statusColor = Colors.teal.shade600;
        statusIcon = Icons.settings_ethernet_rounded;
        statusTitle = 'Connected (Ethernet / VPN)';
        statusSubtitle = 'Wired or virtual tunnel connection established.';
        break;
      case NetworkInterfaceType.offline:
        statusColor = Colors.red.shade600;
        statusIcon = Icons.wifi_off_rounded;
        statusTitle = 'Device is Offline';
        statusSubtitle =
            'No active network interface. Requests will be safely queued until connection is restored.';
        break;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.35), width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              statusColor.withOpacity(0.08),
              Theme.of(context).cardColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              statusTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Pulsing status dot
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            // Quick Status Metrics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricTile(
                  context,
                  label: 'Interface',
                  value: type.displayName,
                  icon: Icons.router_outlined,
                  accentColor: statusColor,
                ),
                _buildMetricTile(
                  context,
                  label: 'Active',
                  value: '${monitor.runningCount}',
                  icon: Icons.sync_rounded,
                  accentColor: Colors.blue,
                ),
                _buildMetricTile(
                  context,
                  label: 'Queued',
                  value: '${monitor.queuedCount}',
                  icon: Icons.pause_circle_outline_rounded,
                  accentColor: Colors.orange,
                ),
                _buildMetricTile(
                  context,
                  label: 'Completed',
                  value: '${monitor.completedCount}',
                  icon: Icons.check_circle_outline_rounded,
                  accentColor: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: accentColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildSimulationControls(
    BuildContext context,
    NetworkMonitorProvider monitor,
  ) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Handover & Disconnect Simulator',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (monitor.isSimulationMode)
                  TextButton.icon(
                    onPressed: () => monitor.useDeviceNetwork(),
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Restore HW'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Simulate network handovers and disconnects to test request recovery.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSimChip(
                  context,
                  label: 'Simulate Wi-Fi',
                  icon: Icons.wifi,
                  color: Colors.green,
                  isSelected: monitor.isSimulationMode &&
                      monitor.currentInterface == NetworkInterfaceType.wifi,
                  onTap: () =>
                      monitor.simulateInterface(NetworkInterfaceType.wifi),
                ),
                _buildSimChip(
                  context,
                  label: 'Simulate Cellular',
                  icon: Icons.cell_tower,
                  color: Colors.blue,
                  isSelected: monitor.isSimulationMode &&
                      monitor.currentInterface == NetworkInterfaceType.cellular,
                  onTap: () =>
                      monitor.simulateInterface(NetworkInterfaceType.cellular),
                ),
                _buildSimChip(
                  context,
                  label: 'Simulate Disconnect (Offline)',
                  icon: Icons.wifi_off,
                  color: Colors.red,
                  isSelected: monitor.isSimulationMode &&
                      monitor.currentInterface == NetworkInterfaceType.offline,
                  onTap: () =>
                      monitor.simulateInterface(NetworkInterfaceType.offline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : color,
      ),
      label: Text(label),
      backgroundColor: isSelected ? color : null,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onPressed: onTap,
    );
  }

  Widget _buildRequestActionSection(
    BuildContext context,
    NetworkMonitorProvider monitor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Continuous Request Controls',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () {
                monitor.enqueueRequest(
                  title: 'Data Package #${monitor.requests.length + 1} (5MB)',
                  totalBytes: 5000000,
                  chunks: 6,
                );
              },
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('Fetch Large Dataset (5MB)'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                for (int i = 1; i <= 3; i++) {
                  monitor.enqueueRequest(
                    title: 'Telemetry Batch #$i (2MB)',
                    totalBytes: 2000000,
                    chunks: 5,
                  );
                }
              },
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('Enqueue Batch (3 Requests)'),
            ),
            if (monitor.queuedCount > 0 && monitor.isOnline)
              OutlinedButton.icon(
                onPressed: () => monitor.retryQueuedRequests(),
                icon: const Icon(Icons.replay_rounded),
                label: Text('Retry Queued (${monitor.queuedCount})'),
              ),
            if (monitor.requests.isNotEmpty)
              TextButton.icon(
                onPressed: () => monitor.clearAllRequests(),
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('Clear All'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildQueueSection(
    BuildContext context,
    NetworkMonitorProvider monitor,
  ) {
    final requests = monitor.requests;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.dns_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Request Queuing System',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Chip(
                  label: Text('${requests.length} Requests'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Requests interrupted during network handover or drops are caught safely and queued without crashing.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const Divider(height: 24),
            if (requests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_done_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No requests in queue',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "Fetch Large Dataset" above to test resilient queuing.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = requests[index];
                  return _buildRequestItemCard(context, item);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestItemCard(BuildContext context, NetworkRequestItem item) {
    Color badgeColor;
    IconData badgeIcon;

    switch (item.status) {
      case RequestStatus.running:
        badgeColor = Colors.blue;
        badgeIcon = Icons.sync_rounded;
        break;
      case RequestStatus.queued:
        badgeColor = Colors.orange;
        badgeIcon = Icons.pause_circle_filled_rounded;
        break;
      case RequestStatus.completed:
        badgeColor = Colors.green;
        badgeIcon = Icons.check_circle_rounded;
        break;
      case RequestStatus.idle:
        badgeColor = Colors.grey;
        badgeIcon = Icons.hourglass_empty_rounded;
        break;
      case RequestStatus.failed:
        badgeColor = Colors.red;
        badgeIcon = Icons.error_outline_rounded;
        break;
    }

    final percent = (item.progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerLow
            .withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isQueued
              ? Colors.orange.withOpacity(0.5)
              : Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(badgeIcon, size: 20, color: badgeColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.status.displayName,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.progress,
              minHeight: 6,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress: $percent% (${(item.transferredBytes / 1000000).toStringAsFixed(1)} / ${(item.totalBytes / 1000000).toStringAsFixed(1)} MB)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (item.retryCount > 0)
                Text(
                  'Retries: ${item.retryCount}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                ),
            ],
          ),
          if (item.lastError != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 14, color: Colors.orange.shade800),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Caught: ${item.lastError}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventLogSection(
    BuildContext context,
    NetworkMonitorProvider monitor,
  ) {
    final logs = monitor.eventLogs;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Handover & Recovery Log',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  'Live Stream',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (logs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No network events recorded yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    Color logColor;
                    IconData logIcon;

                    switch (log.type) {
                      case NetworkLogType.success:
                        logColor = Colors.green;
                        logIcon = Icons.check_circle_outline;
                        break;
                      case NetworkLogType.warning:
                        logColor = Colors.orange;
                        logIcon = Icons.warning_amber_rounded;
                        break;
                      case NetworkLogType.error:
                        logColor = Colors.red;
                        logIcon = Icons.error_outline;
                        break;
                      case NetworkLogType.info:
                        logColor = Colors.blue;
                        logIcon = Icons.info_outline;
                        break;
                    }

                    final timeStr =
                        '${log.timestamp.hour.toString().padLeft(2, '0')}:'
                        '${log.timestamp.minute.toString().padLeft(2, '0')}:'
                        '${log.timestamp.second.toString().padLeft(2, '0')}';

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Icon(logIcon, size: 14, color: logColor),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            log.message,
                            style: TextStyle(
                              fontSize: 12,
                              color: logColor == Colors.blue ? null : logColor,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
