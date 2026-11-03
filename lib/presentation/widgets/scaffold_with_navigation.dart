import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_names.dart';

class ScaffoldWithNavigation extends StatelessWidget {
  const ScaffoldWithNavigation(
      {super.key,
      required this.body,
      required this.title,
      required this.currentPath,
      this.showHeader = false});

  final Widget body;
  final String title;
  final String currentPath;
  final bool showHeader;

  static const _routes = <String>[
    RouteNames.home,
    RouteNames.usuarios,
    RouteNames.recolectores,
    RouteNames.centros,
    RouteNames.publicaciones,
    RouteNames.ofertas,
    RouteNames.reciclaje,
    RouteNames.moderacion,
    RouteNames.mapa,
    RouteNames.soporte,
    RouteNames.sync,
    RouteNames.auditoria,
  ];

  static const _destinations = <(IconData, String)>[
    (Icons.dashboard, 'Dashboard'),
    (Icons.people, 'Usuarios'),
    (Icons.recycling, 'Recolectores'),
    (Icons.location_city, 'Centros'),
    (Icons.inventory, 'Publicaciones'),
    (Icons.offline_bolt, 'Ofertas'),
    (Icons.delete_sweep, 'Reciclaje'),
    (Icons.shield, 'Moderación'),
    (Icons.map, 'Mapa'),
    (Icons.support, 'Soporte'),
    (Icons.sync, 'Sincronización'),
    (Icons.history, 'Auditoría'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              SizedBox(
                width: 256,
                height: constraints.maxHeight,
                child: ColoredBox(
                  color: const Color(0xFF1B5E20),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 20),
                        child: Column(
                          children: [
                            Icon(Icons.eco, size: 48, color: Colors.white),
                            SizedBox(height: 8),
                            Text(
                              'ECOMAP',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _destinations.length,
                          itemBuilder: (context, index) {
                            final destination = _destinations[index];
                            final selected = index == _selectedIndex;
                            return ListTile(
                              selected: selected,
                              selectedTileColor: const Color(0xFF2E7D32),
                              leading: Icon(
                                destination.$1,
                                color: Colors.white,
                              ),
                              title: Text(
                                destination.$2,
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () => context.go(_routes[index]),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: showHeader
                    ? Column(
                        children: [
                          AppBar(
                            title: Text(title),
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                          ),
                          Expanded(child: body),
                        ],
                      )
                    : body,
              ),
            ],
          ),
        ),
      );

  int get _selectedIndex {
    final index = _routes.indexOf(currentPath);
    return index < 0 ? 0 : index;
  }
}
