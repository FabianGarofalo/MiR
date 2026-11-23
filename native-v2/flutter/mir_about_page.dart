// MiR | Acerca de. Marca y créditos correctamente separados.
// Los derechos y licencias del motor se conservan en la sección legal.
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:url_launcher/url_launcher_string.dart';

const _mirDark = Color(0xFF0B191A);
const _mirCard = Color(0xFF132629);
const _mirAccent = Color(0xFF75E0C1);
const _mirText = Color(0xFFEDF6F3);
const _mirMuted = Color(0xFFA4C3BB);
const _mirEdge = Color(0xFF315052);

class MiRAboutPage extends StatelessWidget {
  const MiRAboutPage({super.key});

  Widget _brandBox(Widget child) => Container(
    decoration: BoxDecoration(
      color: _mirCard,
      border: Border.all(color: _mirEdge),
      borderRadius: BorderRadius.circular(15),
    ),
    padding: const EdgeInsets.all(22),
    child: child,
  );

  Widget _link(String title, String url) => TextButton.icon(
    onPressed: () => launchUrlString(url),
    icon: const Icon(Icons.open_in_new_rounded, size: 16),
    label: Text(title),
    style: TextButton.styleFrom(foregroundColor: _mirAccent),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _mirDark,
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _brandBox(Column(children: [
            Image.asset('assets/MiR_logo.png', width: 174, height: 78,
              fit: BoxFit.contain),
            const SizedBox(height: 9),
            const Text('MiR V2',
              style: TextStyle(color: _mirText, fontSize: 22,
                  fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            const Text('Acceso remoto | Windows + Android',
              style: TextStyle(color: _mirMuted, fontSize: 13)),
            const SizedBox(height: 13),
            const Text('Desarrollado por EcoEtika S.A.S. | Distribución gratuita',
              textAlign: TextAlign.center,
              style: TextStyle(color: _mirText, fontSize: 13)),
            const SizedBox(height: 12),
            Image.asset('assets/EcoEtika_logo.png',
              width: 188, height: 62, fit: BoxFit.contain),
            const SizedBox(height: 7),
            _link('Sitio web de EcoEtika', 'https://www.ecoetika.com/'),
          ])),
          const SizedBox(height: 13),
          _brandBox(FutureBuilder<List<String>>(
            future: Future.wait([
              bind.mainGetVersion(),
              bind.mainGetBuildDate(),
            ]),
            builder: (context, snapshot) {
              final details = snapshot.data;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Información técnica',
                  style: TextStyle(color: _mirText, fontSize: 16,
                      fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text('Versión del motor: ${details == null ? "Consultando…" : details[0]}',
                  style: const TextStyle(color: _mirMuted)),
                const SizedBox(height: 7),
                Text('Compilación: ${details == null ? "Consultando…" : details[1]}',
                  style: const TextStyle(color: _mirMuted)),
                const SizedBox(height: 7),
                const Text('La versión de MiR es independiente de la versión del motor.',
                  style: TextStyle(color: _mirMuted, fontSize: 12)),
              ]);
            },
          )),
          const SizedBox(height: 13),
          _brandBox(Theme(
            data: Theme.of(context).copyWith(
              dividerColor: _mirEdge,
              iconTheme: const IconThemeData(color: _mirAccent),
            ),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 7),
              title: const Text('Créditos y licencias de terceros',
                style: TextStyle(color: _mirText, fontSize: 15,
                    fontWeight: FontWeight.w600)),
              subtitle: const Text('Información legal del motor integrado',
                style: TextStyle(color: _mirMuted, fontSize: 12)),
              children: [
                const Align(alignment: Alignment.centerLeft,
                  child: Text(
                    'MiR utiliza componentes del proyecto RustDesk y otras '
                    'dependencias de código abierto. Los derechos de sus autores, '
                    'incluida Purslane Tech Pte. Ltd., permanecen vigentes. '
                    'El código base se distribuye bajo AGPL-3.0, con las '
                    'obligaciones y avisos aplicables. EcoEtika S.A.S. '
                    'es responsable de las modificaciones y la identidad MiR.',
                    style: TextStyle(color: _mirMuted, height: 1.55, fontSize: 12),
                  )),
                const SizedBox(height: 8),
                Wrap(spacing: 4, runSpacing: 0, children: [
                  _link('Código fuente MiR', 'https://github.com/FabianGarofalo/MiR'),
                  _link('Motor original', 'https://github.com/rustdesk/rustdesk'),
                  _link('Licencia AGPL-3.0', 'https://www.gnu.org/licenses/agpl-3.0.html'),
                ]),
                const Text(
                  'Los avisos y archivos de licencias de la distribución se '
                  'conservan junto al ejecutable.',
                  style: TextStyle(color: _mirMuted, fontSize: 11),
                ),
              ],
            ),
          )),
        ]),
      ),
    );
  }
}
