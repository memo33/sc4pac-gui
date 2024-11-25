import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '../viewmodel.dart';
import '../model.dart';
import '../data.dart';
import 'fragments.dart';

class SettingsScreen extends StatelessWidget {

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: const [
        ExpansionTile(
          initiallyExpanded: true,
          leading: Icon(Symbols.passkey),
          title: Text("Authentication (Simtropolis)"),
          children: [
            CookieWidget(),
          ],
        ),
      ],
    );
  }
}

class CookieWidget extends StatefulWidget {
  const CookieWidget({super.key});
  @override State<CookieWidget> createState() => _CookieWidgetState();
}
class _CookieWidgetState extends State<CookieWidget> {
  late Future<SettingsData> settingsFuture;
  late TextEditingController controller = TextEditingController();
  bool changed = false;
  static const simtropolisCookiePlaceholder = "ips4_device_key=<value>; ips4_member_id=<value>; ips4_login_key=<value>";

  @override void initState() {
    super.initState();
    settingsFuture = World.world.client.getSettings();
  }

  void _submit(String? simtropolisCookie) {
    settingsFuture
      .then((settingsData) =>
        settingsData.copyWith(
          auth: simtropolisCookie == null ? [] : [AuthItem(domain: AuthItem.simtropolisDomain, cookie: simtropolisCookie)],
        )
      )
      .then((settingsData) =>
        World.world.client.setSettings(settingsData)
          .then<void>(
            (_) {
              setState(() {
                settingsFuture = World.world.client.getSettings();
                settingsFuture.then(World.world.updateSettings);  // async without awaiting result
                changed = false;
              });
            }
          )
      )
      .catchError((e) => ApiErrorWidget.dialog( ApiError.unexpected("Failed to update cookie", e.toString())));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
"""Basic authentication to Simtropolis is provided via cookies:
• Use your web browser to sign in to Simtropolis with the "remember me" option.
• Inspect the cookies by opening the browser Dev Tools:
    • in Firefox: Storage > Cookies
    • in Chrome: Application > Storage > Cookies
• Replace the <value> placeholders below by the correct cookie values.
  The cookies expire after a few months, so need to be refreshed occasionally.""",
              style: DefaultTextStyle.of(context).style.copyWith(height: 2.5),
            ),
          ),
        ),
        FutureBuilder(
          future: settingsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: ApiErrorWidget(ApiError.from(snapshot.error!)));
            } else if (!snapshot.hasData) {
              return const SizedBox();
            } else {
              if (!changed) {  // avoids text being reset at 2nd change
                final settingsData = snapshot.data!;
                final stAuth = settingsData.auth.where((a) => a.isSimtropolisCookie());
                controller.text = stAuth.isNotEmpty ? stAuth.first.cookie : simtropolisCookiePlaceholder;
              }
              return TextField(
                controller: controller,
                maxLines: null,
                onChanged: (_) {
                  if (!changed) {
                    setState(() { changed = true; });
                  }
                },
              );
            }
          },
        ),
        OverflowBar(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.key_off),
                onPressed: () => _submit(null),
                label: const Text("Reset to default"),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: FilledButton.icon(
                icon: const Icon(Icons.save_outlined),
                onPressed: !changed ? null : () => _submit(controller.text.trim()),
                label: const Text("Save changes"),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
