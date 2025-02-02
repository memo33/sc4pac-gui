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
            CookieWidget(),
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
            value: World.world.settings.refreshChannels,
            onChanged: (refreshChannels) {
              final settings2 = World.world.settings.withRefreshChannels(refreshChannels);
              World.world.updateSettings(settings2);
              World.world.client.setSettings(settings2)
                .catchError((e) => ApiErrorWidget.dialog(ApiError.unexpected("Failed to save settings.", e.toString())));
            },
          ),
        ),
        AboutListTile(
          icon: const Icon(Symbols.info),
          applicationIcon: Image.asset("assets/sc4pac-gui.png", width: 96, height: 96),
          applicationVersion: "Version ${World.world.appInfo.version}\n(with sc4pac CLI version ${World.world.serverVersion})",
          aboutBoxChildren: const [
            AboutMessage(),
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
    return Text.rich(TextSpan(
        children: <InlineSpan>[
          const TextSpan(text: "A mod manager for SimCity 4 plugins.\n\nMore information available at "),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Hyperlink(url: websiteUrl),
          ),
          const TextSpan(text: ".\n\nSource code: "),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Hyperlink(url: sourceUrl),
          ),
        ]
      )
    );
  }
}

class HighlightTextEditingController extends TextEditingController {
  final String keyword;
  late final keywordRegex = RegExp("$keyword|\"|<|>");  // highlights some additional invalid characters
  HighlightTextEditingController(this.keyword);
  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, bool? withComposing}) {
    style ??= const TextStyle();
    final matches = keywordRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return TextSpan(text: text, style: style);
    } else {
      final highlightStyle = createHighlightStyle(context, style);
      return TextSpan(
        style: style,
        children: [
          if (matches.isNotEmpty)
            ...Iterable.generate(matches.length, (i) => i).expand((i) {
              final trailingTextEnd = i < matches.length - 1 ? matches[i+1].start : text.length;
              final trailingTextStart = matches[i].end;
              return [
                if (i == 0 && matches[0].start > 0) TextSpan(text: text.substring(0, matches[0].start)),
                TextSpan(text: matches[i][0], style: highlightStyle),
                if (trailingTextStart < trailingTextEnd) TextSpan(text: text.substring(trailingTextStart, trailingTextEnd)),
              ];
            })
        ],
      );
    }
  }
  static TextStyle createHighlightStyle(BuildContext context, TextStyle style) =>
    style.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.tertiary);
}

class CookieWidget extends StatefulWidget {
  const CookieWidget({super.key});
  @override State<CookieWidget> createState() => _CookieWidgetState();
}
class _CookieWidgetState extends State<CookieWidget> {
  static const _value = "value";
  late TextEditingController controller = HighlightTextEditingController(_value);
  DateTime? pickedDate;
  bool changed = false;
  static const simtropolisCookiePlaceholder = "ips4_device_key=$_value; ips4_member_id=$_value; ips4_login_key=$_value";

  @override void initState() {
    super.initState();
    _initFields();
  }

  void _initFields() {
    controller.text = World.world.settings.stAuth?.cookie ?? simtropolisCookiePlaceholder;
    pickedDate = World.world.settings.stAuth?.expirationDate;
  }

  void _submit(String? simtropolisCookie, DateTime? expirationDate) {
    World.world.client.getSettings()
      .then((settingsData) async {
        if (simtropolisCookie == null) {
          return settingsData.withAuth(auth: []);
        } else {
          final cookieBytes = await AuthItem.obfuscateCookie(simtropolisCookie);
          return settingsData.withAuth(
            auth: [AuthItem(domain: AuthItem.simtropolisDomain, cookieBytes: cookieBytes, expirationDate: expirationDate)],
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
      .catchError((e) => ApiErrorWidget.dialog(ApiError.unexpected("Failed to update cookie", e.toString())));
  }

  String _formatDate(DateTime? d) => d == null ? "unknown" : d.toString().substring(0, 'YYYY-MM-DD'.length);

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
To avoid this limit, authentication to Simtropolis is provided via cookies:
- Use your web browser to sign in to Simtropolis with the "remember me" option.
- Inspect the cookies by opening the browser Dev Tools:
    - in Firefox: Storage > Cookies
    - in Chrome: Application > Storage > Cookies
- Replace the `$_value` placeholders below by the correct cookie values.""",
            )),
          ),
        ),
        ListenableBuilder(
          listenable: World.world,
          builder: (context, child) {
            return TextField(
              decoration: const InputDecoration(
                icon: Icon(Symbols.cookie),
                labelText: "Cookie",
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
        const SizedBox(height: 20),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text("The cookies expire after a few months, so need to be refreshed occasionally. Copy the expiration date from your web browser to receive a reminder when the cookies expired."),
        ),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 250),
                  child: Text("Expiration date: ${_formatDate(pickedDate)}"),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  icon: const Icon(Symbols.acute),
                  label: const Text("3 months from now"),
                  onPressed: () => setState(() {
                    pickedDate = DateTime.now().add(const Duration(days: 90));
                    changed = true;
                  }),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  icon: const Icon(Symbols.edit_calendar),
                  label: const Text("Pick date"),
                  onPressed: () => showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate: DateTime.now().add(const Duration(days: 90)),
                  ).then((date) {
                    if (date != null) {
                      setState(() {
                        pickedDate = date;
                        changed = true;
                      });
                    }
                  }),
                ),
              ],
            ),
          ),
        )),
        const SizedBox(height: 5),
        OverflowBar(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.key_off),
                onPressed: () => _submit(null, null),
                label: const Text("Reset to default"),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: FilledButton.icon(
                icon: const Icon(Icons.save_outlined),
                onPressed: !changed ? null : () => _submit(controller.text.trim(), pickedDate),
                label: const Text("Save changes"),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
