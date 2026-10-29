import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/network_diagnostic_result.dart';
import '../providers/network_diagnostic_provider.dart';

class NetworkDiagnosticDashboard extends StatefulWidget {
  const NetworkDiagnosticDashboard({super.key});

  @override
  State<NetworkDiagnosticDashboard> createState() =>
      _NetworkDiagnosticDashboardState();
}

class _NetworkDiagnosticDashboardState
    extends State<NetworkDiagnosticDashboard> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NetworkDiagnosticProvider>();
      if (provider.health == NetworkHealth.unknown && !provider.isTesting) {
        provider.runDiagnostic();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Diagnostic Dashboard'),
      ),
      body: Consumer<NetworkDiagnosticProvider>(
        builder: (context, provider, child) {
          final result = provider.result;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // =========================================================
                // BUTTONS - MOVED TO THE TOP
                // =========================================================

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: provider.isTesting
                            ? null
                            : () {
                                provider.runDiagnostic();
                              },
                        icon: const Icon(Icons.refresh),
                        label: const Text(
                          'Run Diagnostic Again',
                          textAlign: TextAlign.center,
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: provider.isMonitoring
                          ? FilledButton.tonalIcon(
                              onPressed: () {
                                provider.stopMonitoring();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.withValues(alpha: 0.15),
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: const Text(
                                'Stop Automatic',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: () {
                                provider.startMonitoring();
                              },
                              icon: const Icon(Icons.autorenew),
                              label: const Text(
                                'Start Automatic',
                                textAlign: TextAlign.center,
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),

                if (provider.isMonitoring) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.teal.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            provider.isTesting
                                ? 'Automatic background test in progress...'
                                : 'Automatic Monitoring Active • Next test in ${provider.countdown}s',
                            style: const TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${provider.countdown}s',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // =========================================================
                // TESTING STATUS
                // =========================================================

                if (provider.isTesting)
                  Column(
                    children: [
                      const LinearProgressIndicator(),

                      const SizedBox(height: 12),

                      Text(
                        provider.currentStep,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),

                // =========================================================
                // HEALTH CARD
                // =========================================================

                _buildHealthCard(
                  context,
                  provider,
                ),

                const SizedBox(height: 20),

                // =========================================================
                // DIAGNOSTIC RESULTS
                // =========================================================

                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        _buildDiagnosticRow(
                          context,
                          title: 'Idle Ping',
                          value: _formatPing(
                            result.idlePingMs,
                          ),
                          icon: Icons.speed,
                        ),

                        _buildDivider(),

                        _buildDiagnosticRow(
                          context,
                          title: 'Download Bandwidth',
                          value:
                              '${result.downloadMbps.toStringAsFixed(2)} Mbps',
                          icon: Icons.download,
                        ),

                        _buildDivider(),

                        _buildDiagnosticRow(
                          context,
                          title: 'Download Ping',
                          value: _formatPing(
                            result.downloadPingMs,
                          ),
                          icon: Icons.network_check,
                        ),

                        _buildDivider(),

                        _buildDiagnosticRow(
                          context,
                          title: 'Upload Bandwidth',
                          value:
                              '${result.uploadMbps.toStringAsFixed(2)} Mbps',
                          icon: Icons.upload,
                        ),

                        _buildDivider(),

                        _buildDiagnosticRow(
                          context,
                          title: 'Upload Ping',
                          value: _formatPing(
                            result.uploadPingMs,
                          ),
                          icon: Icons.network_check,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // =========================================================
                // ADAPTIVE MULTIMEDIA CARD (DIFFERENTIATED BY TIER)
                // =========================================================

                _buildAdaptiveContent(
                  context,
                  provider.health,
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // =============================================================
  // HEALTH CARD
  // =============================================================

  Widget _buildHealthCard(
    BuildContext context,
    NetworkDiagnosticProvider provider,
  ) {
    final health = provider.health;

    IconData icon;
    Color healthColor;

    switch (health) {
      case NetworkHealth.excellent:
        icon = Icons.check_circle;
        healthColor = Colors.green;
        break;

      case NetworkHealth.fair:
        icon = Icons.info;
        healthColor = Colors.blue;
        break;

      case NetworkHealth.poor:
        icon = Icons.warning_amber_rounded;
        healthColor = Colors.orange;
        break;

      case NetworkHealth.degraded:
        icon = Icons.error_outline;
        healthColor = Colors.red;
        break;

      case NetworkHealth.unknown:
        icon = Icons.sync;
        healthColor = Theme.of(context).colorScheme.primary;
        break;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              icon,
              size: 56,
              color: healthColor,
            ),
            const SizedBox(height: 12),
            Text(
              health.tierName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: healthColor,
                  ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: healthColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                health.badgeLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: healthColor,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              health.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // DIAGNOSTIC ROW
  // =============================================================

  Widget _buildDiagnosticRow(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            child: Icon(
              icon,
              size: 20,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge,
            ),
          ),

          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // DIVIDER
  // =============================================================

  Widget _buildDivider() {
    return const Divider(
      height: 1,
    );
  }

  // =============================================================
  // ADAPTIVE CONTENT
  // =============================================================

  Widget _buildAdaptiveContent(
    BuildContext context,
    NetworkHealth health,
  ) {
    Color tierColor;
    String modeTitle;
    String modeSubtitle;
    Widget mediaWidget;

    switch (health) {
      case NetworkHealth.excellent:
        tierColor = Colors.green;
        modeTitle = 'Tier 1: Ultra High-Definition Mode';
        modeSubtitle =
            'Bandwidth > 10 Mbps • Full 1080p uncompressed media stream active';
        mediaWidget = _buildTier1ExcellentMedia(context);
        break;

      case NetworkHealth.fair:
        tierColor = Colors.blue;
        modeTitle = 'Tier 2: Standard Definition Mode';
        modeSubtitle =
            'Bandwidth 2 - 10 Mbps • Adaptive 720p compression active';
        mediaWidget = _buildTier2FairMedia(context);
        break;

      case NetworkHealth.poor:
        tierColor = Colors.orange;
        modeTitle = 'Tier 3: Low-Bandwidth Micro-Mode';
        modeSubtitle =
            'Bandwidth < 2 Mbps • High-res suppressed, micro-thumbnail active';
        mediaWidget = _buildTier3PoorMedia(context);
        break;

      case NetworkHealth.degraded:
        tierColor = Colors.red;
        modeTitle = 'Tier 4: Zero-Data Placeholder Mode';
        modeSubtitle =
            'Extreme latency (>1000ms) or packet drop • Media transfer blocked';
        mediaWidget = _buildTier4DegradedMedia(context);
        break;

      case NetworkHealth.unknown:
        tierColor = Theme.of(context).colorScheme.primary;
        modeTitle = 'Evaluating Connection Quality...';
        modeSubtitle =
            'Running diagnostic sequence to dynamically adapt media quality';
        mediaWidget = _buildUnknownPendingMedia(context);
        break;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: tierColor.withValues(alpha: 0.15),
                  child: Icon(
                    health == NetworkHealth.excellent
                        ? Icons.verified
                        : health == NetworkHealth.fair
                            ? Icons.hd
                            : health == NetworkHealth.poor
                                ? Icons.data_saver_on
                                : Icons.shield_outlined,
                    color: tierColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        modeTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        modeSubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    health.badgeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: tierColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: KeyedSubtree(
                key: ValueKey(health),
                child: mediaWidget,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // TIER 1: EXCELLENT (> 10 Mbps) - FULL ULTRA HD
  // =============================================================

  Widget _buildTier1ExcellentMedia(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://picsum.photos/id/1018/1000/500',
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.green[950],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.greenAccent,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.green[900],
                  child: const Center(
                    child: Icon(
                      Icons.photo_library,
                      size: 50,
                      color: Colors.white70,
                    ),
                  ),
                );
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'TIER 1 (> 10 Mbps): UNTHROTTLED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  const Icon(
                    Icons.hd_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '1080p Ultra HD Media (4.8 MB)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Full raw dynamic range • Zero compression • Max bitrate',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'HD 100%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // TIER 2: FAIR (2 - 10 Mbps) - STANDARD BALANCED 720p
  // =============================================================

  Widget _buildTier2FairMedia(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://picsum.photos/id/1018/600/300',
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.blueGrey[900],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.lightBlueAccent,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.blueGrey[800],
                  child: const Center(
                    child: Icon(
                      Icons.photo,
                      size: 50,
                      color: Colors.white70,
                    ),
                  ),
                );
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.network_check, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'TIER 2 (2 - 10 Mbps): ADAPTIVE 720p',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  const Icon(
                    Icons.sd_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '720p Standard Balanced Stream (1.2 MB)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Adaptive 60% compression applied • Fluid performance',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '60% Saved',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // TIER 3: POOR (< 2 Mbps) - LOW-RES MICRO-THUMBNAIL
  // =============================================================

  Widget _buildTier3PoorMedia(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'TIER 3 (< 2 Mbps): DATA THROTTLE ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '-98% Data Saved',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 76,
                  height: 76,
                  color: Colors.orange.withValues(alpha: 0.2),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        'https://picsum.photos/id/1018/120/120',
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.orange.withValues(alpha: 0.2),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.photo_size_select_small_outlined,
                              color: Colors.orange,
                              size: 30,
                            ),
                          );
                        },
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          color: Colors.black.withValues(alpha: 0.65),
                          child: const Text(
                            '240p Micro',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'High-Resolution Stream Suppressed',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Connection is under 2 Mbps. HD stream blocked to prevent buffering. Only a lightweight micro-thumbnail (85 KB) was loaded.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =============================================================
  // TIER 4: DEGRADED - ZERO-DATA PLACEHOLDER
  // =============================================================

  Widget _buildTier4DegradedMedia(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'TIER 4 (EXTREME LATENCY / LOSS): ZERO-DATA MODE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Icon(
                Icons.signal_wifi_connected_no_internet_4_rounded,
                size: 42,
                color: Colors.red,
              ),
              const SizedBox(height: 8),
              const Text(
                'Zero-Data Vector Placeholder',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Severe latency (>1000ms) or packet drop detected.\nNetwork media requests are 100% blocked to keep app responsive.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Data Transferred: 0 KB (Zero Consumption)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

  // =============================================================
  // UNKNOWN / PENDING STATE
  // =============================================================

  Widget _buildUnknownPendingMedia(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text(
              'Analyzing network throughput & latency...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }


  // =============================================================
  // FORMAT PING
  // =============================================================

  String _formatPing(double value) {
    if (value.isInfinite || value.isNaN) {
      return 'Failed';
    }

    return '${value.toStringAsFixed(0)} ms';
  }
}