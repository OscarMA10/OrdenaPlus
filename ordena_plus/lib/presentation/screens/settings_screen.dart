import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordena_plus/presentation/providers/settings_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedIndex = 2;
  final String _version = "1.0.0";

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Ajustes', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal.shade600,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Visualización'),
          _buildGridOption(settings.gridColumns, notifier),

          _buildSectionHeader('Información y Contacto'),
          _buildContactOption(),
          _buildInfoOption(),

          const SizedBox(height: 50),
          Center(
            child: Text(
              'Ordena+ v$_version',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(canvasColor: Colors.teal.shade600),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          backgroundColor: Colors.teal.shade600,
          selectedFontSize: 14,
          unselectedFontSize: 12,
          onTap: (index) {
            if (index == _selectedIndex) return;
            setState(() {
              _selectedIndex = index;
            });
            if (index == 0) {
              context.go('/albums');
            } else if (index == 1) {
              context.go('/');
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Álbumes'),
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.teal.shade800,
        ),
      ),
    );
  }

  Widget _buildGridOption(int columns, SettingsNotifier notifier) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.grid_view),
          title: const Text('Tamaño de cuadrícula'),
          subtitle: Text('$columns columnas'),
        ),
        Slider(
          value: columns.toDouble(),
          min: 3,
          max: 5,
          divisions: 2,
          label: '$columns',
          onChanged: (val) {
            notifier.setGridColumns(val.toInt());
          },
        ),
      ],
    );
  }

  Widget _buildContactOption() {
    return ListTile(
      leading: const Icon(Icons.email),
      title: const Text('Contactar soporte'),
      subtitle: const Text('oscarmedinaamat@gmail.com'),
      onTap: () async {
        final Uri emailLaunchUri = Uri(
          scheme: 'mailto',
          path: 'oscarmedinaamat@gmail.com',
          query: 'subject=Soporte Ordena+',
        );
        try {
          if (await canLaunchUrl(emailLaunchUri)) {
            await launchUrl(emailLaunchUri);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No se pudo abrir la app de correo'),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('Error launching email: $e');
        }
      },
    );
  }

  Widget _buildInfoOption() {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('Sobre Ordena+ y permisos'),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Información importante'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Cómo funciona:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Ordena+ te ayuda a organizar tu galería moviendo tus fotos y videos a carpetas físicas internas dentro de los almacenamientos de tu dispositivo.',
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Permisos:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'La app necesita permiso de "Gestión de todos los archivos" para poder MOVER los archivos reales. '
                    'Esto es necesario para que no ocupes espacio doble (copiando) y para que tu galería de Android refleje los cambios.',
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Seguridad:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Cuando borras un álbum en la app, los archivos NO se borran, se mueven al álbum "Papelera" del almacenamiento en el que estaban situados.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      },
    );
  }
}
