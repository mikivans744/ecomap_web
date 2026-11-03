import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/system_notification.dart';
import '../../../domain/services/gemini_assistant_service.dart';
import '../../../domain/services/system_notification_service.dart';
import '../../providers/dashboard_stats_provider.dart';
import '../../providers/oferta_providers.dart';
import '../../providers/publicacion_providers.dart';
import '../../providers/user_providers.dart';
import '../../widgets/async_states.dart';
import '../../widgets/dashboard/metric_card.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({
    super.key,
    this.geminiAssistant = const NoopGeminiAssistantService(),
    this.notificationService,
    this.onSignOut,
  });

  final GeminiAssistantService geminiAssistant;
  final SystemNotificationService? notificationService;
  final Future<void> Function()? onSignOut;

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  late final SystemNotificationService _notificationService =
      widget.notificationService ?? InMemorySystemNotificationService();
  bool _showAssistant = false;
  bool _isLoading = false;
  final TextEditingController _assistantController = TextEditingController();
  String _assistantReply = '';

  @override
  void dispose() {
    _assistantController.dispose();
    super.dispose();
  }

  Future<void> _askAssistant() async {
    final prompt = _assistantController.text.trim();
    if (!widget.geminiAssistant.isConfigured || prompt.isEmpty || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _assistantReply = '';
    });

    try {
      final response = await widget.geminiAssistant.ask(prompt);
      if (!mounted) {
        return;
      }
      setState(() {
        _assistantReply = response;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _assistantReply = 'No se pudo completar la solicitud: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.onSignOut?.call();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cerrar la sesión.')),
      );
    }
  }

  Future<void> _refreshDashboard() async {
    final activeUsers = usersProvider((zona: null, estadoActivo: true));
    ref.invalidate(activeUsers);
    ref.invalidate(dashboardSolicitudesProvider);
    ref.invalidate(publicacionesProvider((
      estado: null,
      categoria: null,
      estadoActivo: null,
    )));
    ref.invalidate(ofertasProvider((
      estado: null,
      centroId: null,
      recolectorId: null,
      desde: null,
      hasta: null,
    )));
    ref.invalidate(dashboardStatsProvider);
    try {
      await Future.wait([
        ref.read(activeUsers.future),
        ref.read(dashboardSolicitudesProvider.future),
        ref.read(publicacionesProvider((
          estado: null,
          categoria: null,
          estadoActivo: null,
        )).future),
        ref.read(ofertasProvider((
          estado: null,
          centroId: null,
          recolectorId: null,
          desde: null,
          hasta: null,
        )).future),
      ]);
    } catch (error) {
      debugPrint('No se pudo actualizar el dashboard: $error');
    }
  }

  void _retryDashboard() {
    ref.invalidate(usersProvider((zona: null, estadoActivo: true)));
    ref.invalidate(dashboardSolicitudesProvider);
    ref.invalidate(publicacionesProvider((
      estado: null,
      categoria: null,
      estadoActivo: null,
    )));
    ref.invalidate(ofertasProvider((
      estado: null,
      centroId: null,
      recolectorId: null,
      desde: null,
      hasta: null,
    )));
    ref.invalidate(dashboardStatsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('ECOMAP Web'),
          ],
        ),
        actions: [
          if (widget.onSignOut != null)
            IconButton(
              key: const Key('logout_button'),
              tooltip: 'Cerrar sesión',
              onPressed: _signOut,
              icon: const Icon(Icons.logout_outlined),
            ),
          IconButton(
            key: const Key('dashboard_refresh_button'),
            tooltip: 'Actualizar métricas',
            onPressed: _refreshDashboard,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            key: const Key('system_notifications_toggle'),
            tooltip: 'Notificaciones',
            onPressed: () => _showNotifications(context),
            icon: const Icon(Icons.notifications_outlined),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            backgroundColor: AppColors.primary,
            child: Text('AD', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      drawer: const _AdminNavigationDrawer(),
      floatingActionButton: widget.geminiAssistant.isConfigured
          ? FloatingActionButton.extended(
              key: const Key('ai_assistant_toggle'),
              onPressed: () => setState(() => _showAssistant = !_showAssistant),
              icon: const Icon(Icons.smart_toy_outlined),
              label: const Text('Asistente'),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            if (constraints.maxWidth >= 1100)
              const SizedBox(
                width: 240,
                child: _AdminNavigationRail(),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshDashboard,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1400),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Panel administrativo',
                                style: textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Resumen de la actividad de ECOMAP.',
                                style: textTheme.bodyLarge?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _DashboardMetrics(
                                onRetry: _retryDashboard,
                              ),
                              if (_showAssistant) ...[
                                const SizedBox(height: 24),
                                _GeminiAssistantPanel(
                                  controller: _assistantController,
                                  isLoading: _isLoading,
                                  reply: _assistantReply,
                                  onSubmit: _askAssistant,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNotifications(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notificaciones del sistema',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_notificationService.notifications.isEmpty)
                  const Text('Sin notificaciones pendientes')
                else
                  ..._notificationService.notifications.map(
                    (notification) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              notification.priority ==
                                      SystemNotificationPriority.high
                                  ? Icons.error_outline
                                  : Icons.info_outline,
                              color: notification.priority ==
                                      SystemNotificationPriority.high
                                  ? AppColors.error
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notification.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(notification.message),
                                ],
                              ),
                            ),
                            IconButton(
                              key: Key(
                                'acknowledge_notification_${_notificationService.notifications.indexOf(notification)}',
                              ),
                              tooltip: 'Marcar como leída',
                              onPressed: () {
                                _notificationService
                                    .acknowledge(notification.id);
                                Navigator.pop(context);
                                setState(() {});
                                _showNotifications(context);
                              },
                              icon: const Icon(Icons.check_circle_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashboardMetrics extends ConsumerWidget {
  const _DashboardMetrics({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(dashboardStatsProvider).when(
          loading: () => const SizedBox(
            height: 320,
            child: LoadingState(message: 'Cargando métricas...'),
          ),
          error: (error, stackTrace) => SizedBox(
            height: 320,
            child: ErrorState(
              message: 'No se pudieron cargar las métricas.',
              error: error,
              onRetry: onRetry,
            ),
          ),
          data: (stats) => LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 1100
                  ? 4
                  : constraints.maxWidth < 480
                      ? 1
                      : 2;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: crossAxisCount == 1
                        ? 2.3
                        : crossAxisCount >= 4
                            ? 1.4
                            : 1.55,
                    children: [
                      MetricCard(
                        title: 'Usuarios Activos',
                        value: _formatInteger(stats.totalUsuariosActivos),
                        icon: Icons.people_alt_outlined,
                        color: AppColors.primary,
                      ),
                      MetricCard(
                        title: 'Publicaciones Activas',
                        value: _formatInteger(stats.publicacionesActivas),
                        icon: Icons.inventory_2_outlined,
                        color: AppColors.secondary,
                      ),
                      MetricCard(
                        title: 'Ofertas Pendientes',
                        value: _formatInteger(stats.ofertasPendientes),
                        icon: Icons.pending_actions_outlined,
                        color: stats.ofertasPendientes > 0
                            ? AppColors.warning
                            : AppColors.primary,
                        valueColor: stats.ofertasPendientes > 0
                            ? AppColors.warning
                            : null,
                      ),
                      MetricCard(
                        title: 'Material Reciclado',
                        value:
                            _formatRecycledWeight(stats.materialRecicladoTotal),
                        icon: Icons.recycling_outlined,
                        color: AppColors.primary,
                      ),
                      MetricCard(
                        title: 'Reputación Promedio',
                        value:
                            '${stats.reputacionPromedio.toStringAsFixed(1)} ★',
                        icon: Icons.star_outline_rounded,
                        color: AppColors.warning,
                      ),
                      MetricCard(
                        title: 'Solicitudes Pendientes',
                        value: _formatInteger(stats.solicitudesPendientes),
                        icon: Icons.report_problem_outlined,
                        color: stats.solicitudesPendientes > 0
                            ? AppColors.error
                            : AppColors.primary,
                        valueColor: stats.solicitudesPendientes > 0
                            ? AppColors.error
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _DashboardCharts(stats: stats),
                ],
              );
            },
          ),
        );
  }
}

class _DashboardCharts extends StatelessWidget {
  const _DashboardCharts({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final chartWidth = constraints.maxWidth >= 760
              ? (constraints.maxWidth - 16) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: chartWidth,
                child: _ChartCard(
                  title: 'Material reciclado por mes',
                  child: _MonthlyRecyclingChart(stats: stats),
                ),
              ),
              SizedBox(
                width: chartWidth,
                child: _ChartCard(
                  title: 'Distribución por material',
                  child: _MaterialDistributionChart(stats: stats),
                ),
              ),
            ],
          );
        },
      );
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      );
}

class _MonthlyRecyclingChart extends StatelessWidget {
  const _MonthlyRecyclingChart({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.completedTransactions == 0) {
      return const SizedBox(
        height: 240,
        child: Center(child: Text('Sin transacciones completadas.')),
      );
    }

    final maxKilograms = stats.monthlyRecyclingTotals.fold<double>(
      0,
      (maximum, month) => math.max(maximum, month.kilograms),
    );
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxKilograms <= 0 ? 1 : maxKilograms * 1.2,
              barGroups: [
                for (var index = 0;
                    index < stats.monthlyRecyclingTotals.length;
                    index++)
                  BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: stats.monthlyRecyclingTotals[index].kilograms,
                        color: AppColors.primary,
                        width: 22,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
              ],
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem(
                    '${rod.toY.toStringAsFixed(1)} kg',
                    const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final total in stats.monthlyRecyclingTotals)
              Expanded(
                child: Text(
                  _monthAbbreviation(total.month.month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MaterialDistributionChart extends StatelessWidget {
  const _MaterialDistributionChart({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.completedTransactions == 0 || stats.recyclingByMaterial.isEmpty) {
      return const SizedBox(
        height: 240,
        child: Center(child: Text('Sin transacciones completadas.')),
      );
    }

    return SizedBox(
      height: 240,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 38,
                sections: [
                  for (var index = 0;
                      index < stats.recyclingByMaterial.length;
                      index++)
                    PieChartSectionData(
                      value: stats.recyclingByMaterial[index].kilograms,
                      title: '',
                      color: Colors.primaries[index % Colors.primaries.length],
                      radius: 68,
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: stats.recyclingByMaterial.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = stats.recyclingByMaterial[index];
                return Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            Colors.primaries[index % Colors.primaries.length],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.material,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${item.kilograms.toStringAsFixed(1)} kg'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _monthAbbreviation(int month) => const [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ][month - 1];

String _formatInteger(int value) {
  return value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );
}

String _formatRecycledWeight(double kilograms) {
  if (kilograms >= 1000) {
    return '${(kilograms / 1000).toStringAsFixed(1)} t';
  }
  return '${_formatInteger(kilograms.round())} kg';
}

class _GeminiAssistantPanel extends StatelessWidget {
  const _GeminiAssistantPanel({
    required this.controller,
    required this.isLoading,
    required this.reply,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isLoading;
  final String reply;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Asistente ECOMAP',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('ai_assistant_input'),
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Pregúntale al asistente sobre el panel...',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('ai_assistant_submit'),
              onPressed: isLoading ? null : onSubmit,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(isLoading ? 'Consultando...' : 'Consultar'),
            ),
            if (reply.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(reply),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminNavigationRail extends StatelessWidget {
  const _AdminNavigationRail();

  @override
  Widget build(BuildContext context) {
    const navigationItems = [
      _NavigationItem(label: 'Dashboard', icon: Icons.dashboard_outlined),
      _NavigationItem(label: 'Usuarios', icon: Icons.people_outline),
      _NavigationItem(
          label: 'Recolectores', icon: Icons.local_shipping_outlined),
      _NavigationItem(label: 'Centros', icon: Icons.warehouse_outlined),
      _NavigationItem(
        label: 'Publicaciones',
        icon: Icons.inventory_2_outlined,
      ),
      _NavigationItem(label: 'Ofertas', icon: Icons.local_offer_outlined),
      _NavigationItem(label: 'Reciclaje', icon: Icons.recycling_outlined),
      _NavigationItem(label: 'Moderación', icon: Icons.shield_outlined),
      _NavigationItem(label: 'Mapa', icon: Icons.map_outlined),
      _NavigationItem(label: 'Soporte', icon: Icons.support_agent_outlined),
    ];

    return Material(
      color: AppColors.surface,
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.eco_rounded, color: AppColors.primary, size: 28),
                SizedBox(width: 8),
                Text('ECOMAP', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ...navigationItems.map(
            (item) => ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              selected: item.label == 'Dashboard',
              selectedTileColor: AppColors.surfaceVariant,
              selectedColor: AppColors.primary,
              onTap: item.label == 'Usuarios'
                  ? () => context.go('/usuarios')
                  : item.label == 'Recolectores'
                      ? () => context.go('/recolectores')
                      : item.label == 'Centros'
                          ? () => context.go('/centros')
                          : item.label == 'Publicaciones'
                              ? () => context.go('/publicaciones')
                              : item.label == 'Ofertas'
                                  ? () => context.go('/ofertas')
                                  : item.label == 'Reciclaje'
                                      ? () => context.go('/reciclaje')
                                      : item.label == 'Moderación'
                                          ? () => context.go('/moderacion')
                                          : item.label == 'Mapa'
                                              ? () => context.go('/mapa')
                                              : item.label == 'Soporte'
                                                  ? () => context.go('/soporte')
                                                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNavigationDrawer extends StatelessWidget {
  const _AdminNavigationDrawer();

  @override
  Widget build(BuildContext context) {
    const items = [
      'Dashboard',
      'Usuarios',
      'Recolectores',
      'Centros',
      'Publicaciones',
      'Ofertas',
      'Reciclaje',
      'Moderación',
      'Mapa',
      'Soporte',
    ];

    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const ListTile(
              leading: Icon(Icons.eco_rounded, color: AppColors.primary),
              title: Text('ECOMAP Web'),
            ),
            ...items.map(
              (item) => ListTile(
                leading: Icon(_navigationIcon(item)),
                title: Text(item),
                selected: item == 'Dashboard',
                onTap: () {
                  Navigator.pop(context);
                  if (item == 'Usuarios') {
                    context.go('/usuarios');
                  } else if (item == 'Recolectores') {
                    context.go('/recolectores');
                  } else if (item == 'Centros') {
                    context.go('/centros');
                  } else if (item == 'Publicaciones') {
                    context.go('/publicaciones');
                  } else if (item == 'Ofertas') {
                    context.go('/ofertas');
                  } else if (item == 'Reciclaje') {
                    context.go('/reciclaje');
                  } else if (item == 'Moderación') {
                    context.go('/moderacion');
                  } else if (item == 'Mapa') {
                    context.go('/mapa');
                  } else if (item == 'Soporte') {
                    context.go('/soporte');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _navigationIcon(String label) {
  switch (label) {
    case 'Dashboard':
      return Icons.dashboard_outlined;
    case 'Usuarios':
      return Icons.people_outline;
    case 'Recolectores':
      return Icons.local_shipping_outlined;
    case 'Centros':
      return Icons.warehouse_outlined;
    case 'Publicaciones':
      return Icons.inventory_2_outlined;
    case 'Ofertas':
      return Icons.local_offer_outlined;
    case 'Reciclaje':
      return Icons.recycling_outlined;
    case 'Moderación':
      return Icons.shield_outlined;
    case 'Mapa':
      return Icons.map_outlined;
    case 'Soporte':
      return Icons.support_agent_outlined;
    default:
      return Icons.circle_outlined;
  }
}

class _NavigationItem {
  const _NavigationItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
