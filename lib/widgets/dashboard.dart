import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:open_file/open_file.dart';
import 'package:badges/badges.dart' as badges;
import '../data.dart';
import '../model.dart';
import '../viewmodel.dart';
import '../main.dart';
import 'fragments.dart';

class DashboardScreen extends StatefulWidget {
  final Dashboard dashboard;
  final Sc4pacClient client;
  const DashboardScreen(this.dashboard, this.client, {super.key});

  @override State<DashboardScreen> createState() => _DashboardScreenState();

  static Future<String?> showUpdatePlan(UpdatePlan plan) {
    return showDialog(
      context: NavigationService.navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.system_update_alt_outlined),
        title: Text(plan.toInstall.isEmpty ? 'Remove these plugins?' : 'Update these plugins?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...plan.toRemove.expand((pkg) {
                final change = plan.changes[pkg.package]!;
                return [
                  if (change.versionTo == null) Wrap(
                    direction: Axis.horizontal,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Tooltip(message: 'Package will be removed', child: Icon(Icons.remove_circle_outline)),
                      const SizedBox(width: 10),
                      PkgNameFragment(BareModule.parse(pkg.package), asButton: false, colored: false),
                      const SizedBox(width: 12),
                      VersionChangeFragment(change.versionFrom, change.versionTo),
                    ],
                  ),
                ];
              }),
              ...plan.toInstall.map((pkg) {
                final change = plan.changes[pkg.package]!;
                return Wrap(
                  direction: Axis.horizontal,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Tooltip(
                      message: change.versionFrom == null ? 'New' : 'Update',
                      child: Icon(change.versionFrom == null ? Icons.add_circle_outline : Icons.sync_outlined),
                    ),
                    const SizedBox(width: 10),
                    PkgNameFragment(BareModule.parse(pkg.package), asButton: false, colored: false),
                    ...change.versionFrom == change.versionTo
                      ? []
                      : [const SizedBox(width: 12), VersionChangeFragment(change.versionFrom, change.versionTo)],
                    ...!((change.variantTo?.isNotEmpty ?? false) && !mapEquals(change.variantFrom, change.variantTo))
                      ? []
                      : [
                        const SizedBox(width: 10),
                        Wrap(
                          direction: Axis.horizontal,
                          spacing: 5,
                          children: change.variantTo!.entries.map((e) => PackageTileChip.variant(e.key, e.value)).toList(),
                        ),
                      ],
                  ],
                );
              }),
            ],
          ),
        ),
        actions: plan.choices.map((choice) => OutlinedButton(
          child: Text(choice),
          onPressed: () {
            Navigator.pop(context, choice);
          },
        )).toList(),
      ),
    );
  }

  static Future<String?> showWarningsDialog(ConfirmationUpdateWarnings msg) {
    return showDialog(
      context: NavigationService.navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_outlined),
        title: const Text('Continue despite warnings?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: Column(
              children: msg.warnings.entries.expand((e) =>
                (e.value as List<dynamic>).map((w) =>
                  ListTile(
                    title: PkgNameFragment(BareModule.parse(e.key), asButton: false, colored: false),
                    subtitle: Text('$w'),
                    leading: const Icon(Icons.warning_outlined),
                  ),
                )
              ).toList(),
            ),
          ),
        ),
        actions: msg.choices.map((choice) => OutlinedButton(
          child: Text(choice),
          onPressed: () {
            Navigator.pop(context, choice);
          },
        )).toList(),
      ),
    );
  }

  static Future<String?> showVariantDialog(ChoiceUpdateVariant msg) {
    return showDialog(
      context: NavigationService.navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) => SimpleDialog(
        title: Column(
          children: [
            Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.alt_route_outlined, color: Theme.of(context).colorScheme.tertiary)),
            Text('Choose a variant of type "${msg.label}" for ${msg.package}:'),
          ],
        ),
        children: msg.choices.map((choice) => SimpleDialogOption(
          child: ListTile(title: Text(choice), subtitle: msg.descriptions.containsKey(choice) ? Text('${msg.descriptions[choice]}') : null),
          onPressed: () {
            Navigator.pop(context, choice);
          },
        )).toList(),
      ),
    );
  }

}
class _DashboardScreenState extends State<DashboardScreen> {

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: false,
      padding: const EdgeInsets.all(15),

        /*ListenableBuilder(
      listenable: widget.dashboard,
      // child: …,
      builder: (context, child) =>*/ /*Column(*/  // TODO use child for non-changing parts of widget
        // mainAxisSize: MainAxisSize.max,
        // mainAxisAlignment: MainAxisAlignment.start,
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Card(
          //   child: ListenableBuilder(
          //     listenable: widget.client,
          //     builder: (context, child) =>
          //       switch (widget.client.status) {
          //         ClientStatus.connecting => const ListTile(leading: Icon(Icons.wifi_tethering_off), title: Text('Connecting to local sc4pac server...')),
          //         ClientStatus.connected => const ListTile(leading: Icon(Icons.wifi_tethering), title: Text('Connected to local sc4pac server.')),
          //         ClientStatus.serverNotRunning => const ListTile(leading: Icon(Icons.wifi_tethering_error), title: Text('Local sc4pac server is not running. (reconnect not yet implemented)')),
          //         ClientStatus.lostConnection => const ListTile(leading: Icon(Icons.wifi_tethering_error), title: Text('Lost connection to local sc4pac server. (reconnect not yet implemented)')),
          //       }
          //   ),
          // ),
          ListTile(
            leading: const Icon(Symbols.person_pin_circle),
            title: Text('Profile: ${widget.dashboard.profile.name}')
          ),
          ExpansionTile(
            leading: const Icon(Symbols.folder_supervised),
            title: const Text("Plugins folder"),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Path'
                        ),
                        readOnly: true,
                        initialValue: widget.dashboard.profile.paths?.plugins,
                      ),
                    ),
                  ),
                  Tooltip(message: 'Open in file browser', child: IconButton(
                    icon: const Icon(Symbols.open_in_new_down),
                    onPressed: widget.dashboard.profile.paths == null ? null : () {
                      OpenFile.open(widget.dashboard.profile.paths?.plugins);  // TODO does not work in web
                    },
                  )),
                ],
              ),
            ],
          ),
          const ExpansionTile(
            leading: Icon(Icons.layers_outlined),
            title: Text("Channels"),
            children: [
              ChannelsList(),
            ],
          ),
          ListenableBuilder(
            listenable: widget.dashboard,
            builder: (context, child) => VariantsWidget(widget.dashboard.variantsFuture),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 5),
            child: FilledButton.icon(
              icon: const Icon(Icons.refresh),
              onPressed: widget.dashboard.updateProcess?.status == UpdateStatus.running ? null : () {
                // Here we use global context (instead of current widget's
                // context) so that update process can show dialog popups even
                // when the current screen is disposed.
                setState(() {
                  widget.dashboard.updateProcess = UpdateProcess(  // TODO ensure that previous ws was closed
                    onFinished: (status) => setState(() {  // triggers rebuild of DashboardScreen
                      if (status == UpdateStatus.finished) {  // no error/no canceled
                        widget.dashboard.clearPendingUpdates();
                      }
                      widget.dashboard.fetchVariants();
                    }),
                  );
                });
              },
              label: const Text('Update All'),
            ),
          ),
          if (widget.dashboard.updateProcess != null)
            Card.outlined(
              child: UpdateWidget(widget.dashboard.updateProcess!),
            ),
          if (widget.dashboard.updateProcess != null && widget.dashboard.updateProcess!.status != UpdateStatus.running)
            ElevatedButton(
              onPressed: () => setState(() {
                widget.dashboard.updateProcess = null;  // TODO ensure that ws was closed
              }),
              child: const Text('Clear Log'),
            ),
        ],
      )/*,
    )*/
    /*)*/;
  }
}

class DashboardIcon extends StatelessWidget {
  final bool selected;
  final Dashboard dashboard;
  const DashboardIcon(this.dashboard, {required this.selected, super.key});
  @override Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dashboard,
      builder: (context, child) {
        final icon = Icon(selected ? Icons.speed : Icons.speed_outlined);
        if (dashboard.pendingUpdates.isEmpty) {
          return icon;
        } else {
          return badges.Badge(
            badgeContent: Text(
              dashboard.pendingUpdates.length.toString(),
              style: DefaultTextStyle.of(context).style.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            ),
            badgeAnimation: const badges.BadgeAnimation.scale(),
            badgeStyle: badges.BadgeStyle(badgeColor: Theme.of(context).colorScheme.secondary),
            child: icon,
          );
        }
      },
    );
  }
}

class InlineIcon extends StatelessWidget {
  final IconData? iconData;
  final double scale;
  const InlineIcon(this.iconData, {super.key, this.scale = 1.0});
  @override Widget build(BuildContext context) {
    var size = Theme.of(context).textTheme.bodyMedium?.fontSize;
    if (size != null) size *= scale;
    return Icon(iconData, applyTextScaling: true, size: size);
  }
}

class VersionChangeFragment extends StatelessWidget {
  final String? versionFrom;
  final String? versionTo;
  const VersionChangeFragment(this.versionFrom, this.versionTo, {super.key});
  @override Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...versionFrom == null ? [] : [Text(versionFrom!), const InlineIcon(Icons.arrow_right, scale: 1.4)],
        versionTo != null ? Text(versionTo!) : const InlineIcon(Icons.block),
      ],
    );
  }
}

class UpdateWidget extends StatefulWidget {
  final UpdateProcess proc;
  const UpdateWidget(this.proc, {super.key});
  @override State<UpdateWidget> createState() => _UpdateWidgetState();
}
class _UpdateWidgetState extends State<UpdateWidget> {

  @override
  void dispose() {
    debugPrint('Disposing websocket.');  // TODO
    // ws.sink.close(); TODO
    super.dispose();
  }

  static String _plural(int count, String singular) => count == 1 ? '$count $singular' : '$count ${singular}s';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: widget.proc.stream,  // StreamBuilder does not rebuild at every stream element, but only for a subsequence of snapshots (framerate-dependent)
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // debugPrint('=====> data: ${snapshot.data}');  // TODO
        } else if (snapshot.hasError) {
          debugPrint('=====> error: ${snapshot.error}');
        } else {
          debugPrint('=====> data pending: ${snapshot.data}');
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            shrinkWrap: true,  // important for nesting inside scrollables
            children: [
              ElevatedButton(
                onPressed: widget.proc.status != UpdateStatus.running ? null : () => widget.proc.cancel(),
                child: const Text('Cancel'),
              ),
              // const ListTile(title: Text('Updating…')),
              if (widget.proc.downloads.isNotEmpty)
                ExpansionTile(
                  leading: widget.proc.downloadsFailed ? const Icon(Icons.block_outlined)
                    : widget.proc.downloadsCompleted ? const Icon(Icons.check_circle_outline)
                    : widget.proc.status != UpdateStatus.running ? const Icon(Icons.block_outlined)
                    : const CircularProgressIndicator(),
                  title: Text(widget.proc.downloadsFailed ? 'Downloading assets failed.' : widget.proc.downloadsCompleted ? 'Downloads completed.' : 'Downloading assets.'),
                  children: widget.proc.downloads.map((url) => DownloadProgressWidget(widget.proc, url: url)).toList(),
                ),
              if (widget.proc.extractionProgress != null)
                ListTile(
                  leading: widget.proc.extractionFinished ? const Icon(Icons.check_circle_outline)
                    : widget.proc.status != UpdateStatus.running ? const Icon(Icons.block_outlined)
                    : const CircularProgressIndicator(),
                  title: !widget.proc.extractionFinished
                    ? Wrap(
                        spacing: 10,
                        children: [
                          const Text('Extracting'),
                          PkgNameFragment(BareModule.parse(widget.proc.extractionProgress!.package), asButton: false, colored: false),
                        ],
                      )
                    : const Text('Extraction completed.'),
                  subtitle: LinearProgressIndicator(
                    value: widget.proc.extractionProgress!.progress.numerator.toDouble() / widget.proc.extractionProgress!.progress.denominator,
                    semanticsLabel: 'Extraction progress indicator',
                  ),
                ),
              if (widget.proc.status != UpdateStatus.running)
                widget.proc.err != null && widget.proc.err!.type != '/error/aborted'
                ? ApiErrorWidget(widget.proc.err!)  // if aborted via dialog, we show a different icon via the branch below
                : ListTile(
                  leading: Icon(widget.proc.status == UpdateStatus.finished ? Icons.check_circle_outline : Icons.block_outlined),  // canceled or finishedWithError
                  title: Text(widget.proc.err?.title ?? (
                      widget.proc.status == UpdateStatus.canceled ? 'Operation canceled.' :
                      (widget.proc.plan?.nothingToDo ?? false) ? 'Everything is up-to-date.' :
                      (widget.proc.plan?.toInstall.isEmpty ?? false) ? 'Finished removing ${_plural(widget.proc.plan?.toRemove.length ?? 0, 'plugin')}.' :
                      'Finished updating ${_plural(widget.proc.plan?.toInstall.length ?? 0, 'plugin')}.'
                  )),
                ),
            ],
          ),
        );
      }
    );
  }
}

class DownloadProgressWidget extends StatelessWidget {
  final String url;
  final bool? success;
  final int? expectedSize;
  final int? currentSize;
  late final double? value;

  DownloadProgressWidget(UpdateProcess proc, {required this.url, super.key})
    : success = proc.downloadSuccess[url],
      expectedSize = proc.downloadLength[url],
      currentSize = proc.downloadDownloaded[url]
  {
    value = (expectedSize != null && currentSize != null)
        ? min(1.0, max(0.0, currentSize!.toDouble() / max(expectedSize!, 1)))
        : (success != null) ? (success! ? 1.0 : 0.0)
        : proc.status != UpdateStatus.running ? 0.0
        : null;
  }

  static String _formatFileSize(int length) {
    if (length < (1 << 20)) {
      return '${(length.toDouble() / (1 << 10)).toStringAsFixed(1)} kiB';
    } else if (length < (1 << 30)) {
      return '${(length.toDouble() / (1 << 20)).toStringAsFixed(1)} MiB';
    } else {
      return '${(length.toDouble() / (1 << 30)).toStringAsFixed(1)} GiB';
    }
  }

  @override Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(success == null ? Icons.downloading_outlined : success! ? Icons.download_done : Icons.dangerous_outlined),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(url)),
          Text([
            if (currentSize != null) _formatFileSize(currentSize!),
            if (expectedSize != null) _formatFileSize(expectedSize!),
          ].join(' / ')),
        ],
      ),
      subtitle: LinearProgressIndicator(
        value: value,
        semanticsLabel: 'Asset download progress indicator',
      ),
    );
  }
}

class VariantsWidget extends StatelessWidget {
  final Future<Map<String, dynamic>> futureJson;
  const VariantsWidget(this.futureJson, {super.key});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.alt_route_outlined),
      title: const Text("Variants"),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder(
          future: futureJson,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: ApiErrorWidget(ApiError.from(snapshot.error!)));
            } else if (!snapshot.hasData) {
              return const SizedBox();
            } else {
              return VariantsTable(snapshot.data!);
            }
          },
        ),
      ],
    );
  }
}

class VariantsTable extends StatefulWidget {
  final Map<String, dynamic> variants;
  const VariantsTable(this.variants, {super.key});
  @override State<VariantsTable> createState() => _VariantsTableState();
}
class _VariantsTableState extends State<VariantsTable> {
  @override
  Widget build(BuildContext context) {
    if (widget.variants.isEmpty) {
      return const Text("No variants installed yet.");
    } else {
      final entries = (widget.variants.entries.map((e) => (key: e.key, value: e.value, keyParts: e.key.split(':')))).toList();
      entries.sort((a, b) {  // first global, then local variants
        final result = a.keyParts.length.compareTo(b.keyParts.length);
        return result != 0 ? result : a.key.compareTo(b.key);
      });
      return ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: Table(
        columnWidths: const {
          0: FlexColumnWidth(0.65),   // variant
          1: IntrinsicColumnWidth(),  // arrow
          2: FlexColumnWidth(0.35),   // value
          3: IntrinsicColumnWidth(),  // remove-button
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: entries.map((e) {
          return TableRow(
            children: [
              e.keyParts.length >= 3 ?
                Align(
                  alignment: Alignment.centerLeft,
                  child: PkgNameFragment(BareModule(e.keyParts[0], e.keyParts[1]),
                    asButton: true,
                    localVariant: e.keyParts.sublist(2).join(':'),
                    refreshParent: null,  // for now, we do not pass a refresh callback, as package page just toggles explicit packages which currenty are not relevant for dashboard
                  ),
                ) : Padding(padding: PkgNameFragment.padding, child: Text(e.key)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.arrow_right_alt)),
              Text(e.value.toString()),
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Tooltip(message: 'Reset variant', child: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    setState(() {
                      widget.variants.remove(e.key);
                      World.world.client.variantsReset([e.key], profileId: World.world.profile.id);  // we do not need to await result
                    });
                  },
                )),
              ),
            ],
          );
        }).toList(),
      ));
    }
  }
}

class ChannelsList extends StatefulWidget {
  const ChannelsList({super.key});
  @override State<ChannelsList> createState() => _ChannelsListState();
}
class _ChannelsListState extends State<ChannelsList> {
  late Future<List<String>> urlsFuture;
  late TextEditingController controller = TextEditingController();
  bool changed = false;

  @override void initState() {
    super.initState();
    urlsFuture = World.world.client.channelsList(profileId: World.world.profile.id);
  }

  List<String> _parseUrls(String text) => text.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();

  String _stringifyUrls(List<String> urls) => urls.isEmpty ? "" : "${urls.join('\n')}\n";

  void _submit(List<String> urls) {
    World.world.client.channelsSet(urls, profileId: World.world.profile.id).then(
      (_) {
        setState(() {
          urlsFuture = World.world.client.channelsList(profileId: World.world.profile.id);
          changed = false;
        });
      },
      onError: (e) => ApiErrorWidget.dialog(ApiError.unexpected("Malformed channel URLs", "Something does not look like a proper URL.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text("Channels contain definitions for packages you can install."
            " Append additional channel URLs below. The first URL has the highest priority."),
        ),
        FutureBuilder(
          future: urlsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: ApiErrorWidget(ApiError.from(snapshot.error!)));
            } else if (!snapshot.hasData) {
              return const SizedBox();
            } else {
              if (!changed) {  // avoids text being reset at 2nd change
                controller.text = _stringifyUrls(snapshot.data!);
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
                icon: const Icon(Icons.layers_clear_outlined),
                onPressed: () => _submit([]),
                label: const Text("Reset to default"),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: FilledButton.icon(
                icon: const Icon(Icons.save_outlined),
                onPressed: !changed ? null : () => _submit(_parseUrls(controller.text)),
                label: const Text("Save changes"),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
