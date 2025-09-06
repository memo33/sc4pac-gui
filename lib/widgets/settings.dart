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
      children: [
        const ExpansionTile(
          initiallyExpanded: false,
          leading: Icon(Symbols.passkey),
          title: Text("Authentication (Simtropolis)"),
          children: [
            CredentialsWidget(),
          ],
        ),
        ExpansionTile(
          leading: const Icon(Symbols.folder_managed),
          title: const Text("Profiles configuration folder"),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text("This folder contains configuration files that store application settings as well as your profiles."),
            ),
            FutureBuilder<Profiles>(
              future: World.world.profilesFuture,
              builder: (context, snapshot) =>
                snapshot.hasData ? PathField(path: snapshot.data!.profilesDir) : const SizedBox(),
            ),
          ],
        ),
        ListenableBuilder(
          listenable: World.world,
          builder: (context, child) => SwitchListTile(
            title: const Text("Refresh channels before every Update"),
            subtitle: const Text(
              "If disabled (recommended), the channels are cached for half an hour to improve efficiency."
            ),
            value: World.world.settings?.refreshChannels ?? false,
            onChanged: (refreshChannels) {
              final settings2 = World.world.settings?.withRefreshChannels(refreshChannels);
              if (settings2 != null) {
                World.world.updateSettings(settings2);
                World.world.client.setSettings(settings2)
                  .catchError((e) => ApiErrorWidget.dialog(ApiError.unexpected("Failed to save settings.", e.toString())));
              }
            },
          ),
        ),
        AboutListTile(
          icon: const Icon(Symbols.info),
          applicationIcon: Image.asset("assets/sc4pac-gui.png", width: 96, height: 96),
          applicationVersion: "Version ${World.world.appInfo.version}\n(with sc4pac CLI version ${World.world.serverVersion})",
          aboutBoxChildren: [
            const AboutMessage(),
            const SizedBox(height: 10),
            TextButton(
              child: const Text("Show debug info"),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    content: SingleChildScrollView(child: DebugInfoCard(ApiErrorWidget.createDebugInfo(null).join("\n"))),
                    actions: [
                      OutlinedButton(
                        child: const Text("Dismiss"),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                );
              }
            ),
          ],
        ),
      ],
    );
  }
}

class AboutMessage extends StatelessWidget {
  static const websiteUrl = "https://memo33.github.io/sc4pac/";
  static const sourceUrl = "https://github.com/memo33/sc4pac-gui";
  const AboutMessage({super.key});
  @override Widget build(BuildContext context) {
    return const Text.rich(TextSpan(
        children: <InlineSpan>[
          TextSpan(text: "A mod manager for SimCity 4 plugins.\n\nMore information available at "),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Hyperlink(url: websiteUrl),
          ),
          TextSpan(text: ".\n\nSource code: "),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Hyperlink(url: sourceUrl),
          ),
        ]
      )
    );
  }
}

class CredentialsWidget extends StatefulWidget {
  const CredentialsWidget({super.key});
  @override State<CredentialsWidget> createState() => _CredentialsWidgetState();
}
class _CredentialsWidgetState extends State<CredentialsWidget> {
  late TextEditingController controller = TextEditingController();
  bool changed = false;

  @override void initState() {
    super.initState();
    _initFields();
  }

  void _initFields() {
    controller.text = World.world.settings?.stAuth?.token ?? "";
  }

  void _submit(String? simtropolisToken) {
    World.world.client.getSettings()
      .then((settingsData) async {
        if (simtropolisToken == null) {
          return settingsData.withAuth(auth: []);
        } else {
          final tokenBytes = await AuthItem.obfuscateToken(simtropolisToken);
          return settingsData.withAuth(
            auth: [AuthItem(domain: AuthItem.simtropolisDomain, tokenBytes: tokenBytes)],
          );
        }
      })
      .then((settingsData) {
        setState(() => changed = false);
        World.world.updateSettings(settingsData);
        return World.world.client.setSettings(settingsData)
          .then<void>(
            (_) {
              setState(() {
                _initFields();
                changed = false;
              });
            }
          );
      })
      .catchError((e) => ApiErrorWidget.dialog(ApiError.unexpected("Failed to update token", e.toString())));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(top: 10, bottom: 20),
            child: SelectionArea(child: MarkdownText(
"""Without signing in, Simtropolis limits downloads to a maximum of 20 files per day.
To avoid this limit:
- Sign in to Simtropolis.
- Generate a personal authentication token at https://community.simtropolis.com/sc4pac/my-token/
- Paste the token here.""",
            )),
          ),
        ),
        ListenableBuilder(
          listenable: World.world,
          builder: (context, child) {
            return TextField(
              decoration: const InputDecoration(
                icon: Icon(Symbols.key),
                labelText: "Token",
                hintText: "Paste your Simtropolis token here",
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              style: const TextStyle(fontFamily: "monospace"),
              controller: controller,
              maxLines: null,
              onChanged: (_) {
                if (!changed) {
                  setState(() { changed = true; });
                }
              },
            );
          },
        ),
        const SizedBox(height: 10),
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
