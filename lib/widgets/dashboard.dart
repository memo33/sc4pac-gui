import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:collection/collection.dart';
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
      context: NavigationService.navigatorKey.currentContext!,  // We use global context so that update process can show dialog popups even when the current screen is disposed.
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
                      const PendingUpdateStatusIcon(PendingUpdateStatus.remove),
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
                    PendingUpdateStatusIcon(change.versionFrom == null ? PendingUpdateStatus.add : PendingUpdateStatus.reinstall),
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
      barrierDismissible: true,  // allow to cancel update process without selecting a variant
      builder: (context) {
        final hintStyle = TextStyle(color: Theme.of(context).hintColor);
        return SimpleDialog(
          title: Column(
            children: [
              Padding(padding: const EdgeInsets.all(10), child: VariantIcon(color: Theme.of(context).colorScheme.tertiary)),
              MarkdownText('## Choose a variant of type `${msg.variantId}` for `pkg=${msg.package}`:\n\n${msg.info.description ?? ""}'),
              const Divider(),
            ],
          ),
          children: msg.choices.map((choice) => SimpleDialogOption(
            child: ListTile(
              title: Text(choice),
              subtitle: msg.info.valueDescriptions.containsKey(choice) ? Text('${msg.info.valueDescriptions[choice]}', style: hintStyle) : null,
            ),
            onPressed: () {
              Navigator.pop(context, choice);
            },
          )).toList(),
        );
      }
    );
  }

  static Future<String?> showRemoveUnresolvablePkgsDialog(ConfirmationRemoveUnresolvablePackages msg) {
    return showDialog(
      context: NavigationService.navigatorKey.currentContext!,
      barrierDismissible: true,  // allow to cancel update process without selection
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_outlined),
        title: const Text('Remove these plugins?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MarkdownText(
"""The following packages could not be resolved.
Maybe they have been renamed or deleted from the corresponding channel, so the metadata cannot be found in any of your channels.
(If a large number of packages is affected, you might have deleted an entire channel by accident.)

### Do you want to *permanently* remove these unresolvable packages from your Plugins?"""
              ),
              const SizedBox(height: 10),
              ...msg.packages.map((pkg) => PkgNameFragment(BareModule.parse(pkg), asButton: false, colored: false)),
            ],
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

  static Future<String?> showRemoveConflictingPkgsDialog(ChoiceRemoveConflictingPackages msg) {
    return showDialog(
      context: NavigationService.navigatorKey.currentContext!,
      barrierDismissible: true,
      builder: (context) => RemoveConflictingPkgsDialog(msg),
    );
  }

}
class _DashboardScreenState extends State<DashboardScreen> {

  @override
  void initState() {
    widget.dashboard.updateProcess ??= UpdateProcess(  // initial check for metadata updates without installing anything
      pendingUpdates: widget.dashboard.pendingUpdates,
      isBackground: true,
      onFinished: widget.dashboard.onUpdateFinished,
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.dashboard,
      builder: (context, child) => ListView(
        shrinkWrap: false,
        padding: const EdgeInsets.all(15),
        children: <Widget>[
          ExpansionTile(
            leading: const Icon(Symbols.person_pin_circle),
            title: Text('Profile: ${widget.dashboard.profile.name}'),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                direction: Axis.horizontal,
                spacing: 20,
                runSpacing: 10,
                children: [
                  FutureBuilder(
                    future: World.world.profilesFuture,
                    builder: (context, snapshot) =>
                      snapshot.hasData ? ProfileSelectMenu(profiles: snapshot.data!) : const SizedBox(),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Symbols.add_location),
                    onPressed: () {
                      World.world.reloadProfiles(createNewProfile: true);
                    },
                    label: const Text("New"),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
          ExpansionTile(
            leading: const Icon(Symbols.folder_supervised),
            title: const Text("Folders"),
            children: [
              ...switch (widget.dashboard.profile.paths?.plugins) {
                null => [],
                String path => [
                  const ListTile(title: Text("Plugins"), leading: Icon(Symbols.folder_special)),
                  PathField(path: path),
                ],
              },
              ...switch (widget.dashboard.profile.paths?.cache) {
                null => [],
                String path => [
                  const ListTile(title: Text("Download cache"), leading: Icon(Symbols.cloud_download)),
                  PathField(path: path),
                ],
              },
            ],
          ),
          const ExpansionTile(
            leading: Icon(Symbols.stacks),
            title: Text("Channels"),
            children: [
              ChannelsList(),
            ],
          ),
          ListenableBuilder(
            listenable: widget.dashboard,
            builder: (context, child) => VariantsWidget(widget.dashboard.variantsFuture),
          ),
          ListenableBuilder(
            listenable: widget.dashboard.pendingUpdates,
            builder: (context, child) => PendingUpdatesWidget(widget.dashboard),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 5),
            child: FilledButton.icon(
              icon: const Icon(Icons.refresh),
              onPressed: widget.dashboard.updateProcess?.status == UpdateStatus.running ? null : () {
                setState(() {
                  widget.dashboard.updateProcess = UpdateProcess(  // TODO ensure that previous ws was closed
                    pendingUpdates: widget.dashboard.pendingUpdates,
                    onFinished: widget.dashboard.onUpdateFinished,
                  );
                });
              },
              label: const Text("Update All"),
            ),
          ),
          if (widget.dashboard.updateProcess?.isBackground == false)
            Card.outlined(
              child: UpdateWidget(widget.dashboard.updateProcess!),
            ),
          if (widget.dashboard.updateProcess?.isBackground == false && widget.dashboard.updateProcess?.status != UpdateStatus.running)
            ElevatedButton(
              onPressed: () => setState(() {
                widget.dashboard.updateProcess = null;  // TODO ensure that ws was closed
              }),
              child: const Text('Clear Log'),
            ),
        ],
      ),
    );
  }
}

class RemoveConflictingPkgsDialog extends StatefulWidget {
  final ChoiceRemoveConflictingPackages msg;
  const RemoveConflictingPkgsDialog(this.msg, {super.key});
  @override State<RemoveConflictingPkgsDialog> createState() => _RemoveConflictingPkgsDialog();
}
class _RemoveConflictingPkgsDialog extends State<RemoveConflictingPkgsDialog> {
  int? _selection;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.warning_outlined),
      title: const Text('Remove conflicting packages?'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownText(
"""The packages ${widget.msg.conflict.map((pkg) => "`pkg=$pkg`").join(" and ")} are _in conflict_ with each other and cannot be installed at the same time.

Decide which of the following packages you want to uninstall to resolve the conflict.
(Sometimes, choosing different package _variants_ can resolve the conflict, as well.)"""
            ),
            const SizedBox(height: 10),
            ...List.generate(widget.msg.explicitPackages.length, (idx) =>
              RadioListTile<int>(
                title: Text("Uninstall Option ${idx + 1}"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.msg.explicitPackages[idx].map((pkg) => PkgNameFragment(BareModule.parse(pkg), asButton: false, colored: false)).toList(),
                ),
                value: idx,
                groupValue: _selection,
                onChanged: (int? value) {
                  setState(() => _selection = idx );
                }
              )
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: switch(_selection) {
            null => null,
            int idx => () => Navigator.pop(context, idx < widget.msg.choices.length ? widget.msg.choices[idx] : widget.msg.choices.last),
          },
          child: const Text("OK, remove selected packages"),
        ),
        OutlinedButton(
          onPressed: () { Navigator.pop(context, widget.msg.choices.last); },
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}

class ProfileSelectMenu extends StatefulWidget {
  final Profiles profiles;
  const ProfileSelectMenu({required this.profiles, super.key});
  @override State<ProfileSelectMenu> createState() => _ProfileSelectMenuState();
}
class _ProfileSelectMenuState extends State<ProfileSelectMenu> {
  late final TextEditingController _controller = TextEditingController(text: widget.profiles.currentProfile()?.name);

  void _submit(String profileId) {
    World.world.client.switchProfile(profileId)
      .then(
        (_) => World.world.reloadProfiles(createNewProfile: false),  // TODO avoid hard reload of everything
        onError: ApiErrorWidget.dialog,
      );
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = widget.profiles.currentProfile()?.id;
    return DropdownMenu<String?>(
      controller: _controller,
      width: 360,
      onSelected: (id) {
        if (id != null && id != selectedId) _submit(id);
      },
      leadingIcon: const Icon(Symbols.mode_of_travel),
      initialSelection: selectedId,
      label: const Text("Profiles"),
      menuStyle: const MenuStyle(
        visualDensity: VisualDensity(horizontal: 0, vertical: -2),
      ),
      enableSearch: false,  // to avoid mismatched highlights in case a profile names is a substring of another, see https://github.com/flutter/flutter/issues/136735
      dropdownMenuEntries: widget.profiles.profiles.map((profile) {
        final color = Theme.of(context).colorScheme.primary;
        return DropdownMenuEntry<String?>(
          value: profile.id,
          label: profile.name,
          labelWidget: Text(profile.name, style: profile.id == selectedId ? TextStyle(color: color) : null),
          leadingIcon: profile.id == selectedId ? Icon(Symbols.pin_drop, color: color) : const Icon(null),
        );
      }).toList(),
    );
  }
}

class DashboardIcon extends StatelessWidget {
  final bool selected;
  final Dashboard dashboard;
  const DashboardIcon(this.dashboard, {required this.selected, super.key});
  @override Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dashboard.pendingUpdates,
      builder: (context, child) {
        final icon = Icon(selected ? Icons.speed : Icons.speed_outlined);
        final count = dashboard.pendingUpdates.getCount();
        if (count == 0) {
          return icon;
        } else {
          return badges.Badge(
            badgeContent: Text(
              count.toString(),
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
    return ListenableBuilder(
      listenable: widget.proc,  // does not notify at every stream element, but only for a subsequence of snapshots (framerate-dependent)
      builder: (context, child) {
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
                  leading: Icon(
                    widget.proc.isBackground
                    ? (widget.proc.plan?.nothingToDo ?? false ? Icons.check_circle_outline : Icons.update_outlined)
                    : widget.proc.status == UpdateStatus.finished ? Icons.check_circle_outline : Icons.block_outlined  // canceled or finishedWithError
                  ),
                  title: Text(widget.proc.err?.title ?? (
                      widget.proc.isBackground ? _pendingUpdatesLabel(widget.proc) : _finishedLabel(widget.proc)
                  )),
                ),
            ],
          ),
        );
      }
    );
  }

  String _finishedLabel(UpdateProcess proc) {
    return
      widget.proc.status == UpdateStatus.canceled ? 'Operation canceled.' :
      (widget.proc.plan?.nothingToDo ?? false) ? 'Everything is up-to-date.' :
      (widget.proc.plan?.toInstall.isEmpty ?? false) ? 'Finished removing ${_plural(widget.proc.plan?.toRemove.length ?? 0, 'plugin')}.' :
      'Finished updating ${_plural(widget.proc.plan?.toInstall.length ?? 0, 'plugin')}.';
  }

  String _pendingUpdatesLabel(UpdateProcess proc) {
    if (proc.plan == null) {
      return "Updates available";  // a variant needs to be selected before knowing how many packages to update
    } else if (proc.plan?.nothingToDo ?? false) {
      return "Everything is up-to-date.";
    } else if (proc.plan?.toInstall.isEmpty ?? false) {
      return "${proc.plan?.toRemove.length ?? 0} updates available";
    } else {
      return "${proc.plan?.toInstall.length ?? 0} updates available";
    }
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
        ? math.min(1.0, math.max(0.0, currentSize!.toDouble() / math.max(expectedSize!, 1)))
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

class VariantIcon extends StatelessWidget {
  final Color? color;
  const VariantIcon({this.color, super.key});
  @override Widget build(BuildContext context) => RotatedBox(quarterTurns: 1, child: Icon(Symbols.alt_route, color: color));
}

class VariantsWidget extends StatelessWidget {
  final Future<VariantsList> futureJson;
  const VariantsWidget(this.futureJson, {super.key});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const VariantIcon(),
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
              final variants = snapshot.data!.variants;
              return VariantsTable(variants);
            }
          },
        ),
      ],
    );
  }
}

class VariantsTable extends StatefulWidget {
  final Map<String, ({String value, bool unused})> variants;
  const VariantsTable(this.variants, {super.key});
  @override State<VariantsTable> createState() => _VariantsTableState();
}
class _VariantsTableState extends State<VariantsTable> {
  @override
  Widget build(BuildContext context) {
    if (widget.variants.isEmpty) {
      return const Padding(padding: listViewTextPadding, child: Text("No variants installed yet."));
    } else {
      final entries = (widget.variants.entries.map((e) => (key: e.key, value: e.value.value, keyParts: e.key.split(':')))).toList();
      entries.sort((a, b) {  // first global, then local variants (first leafs, then nodes -> recursively)
        int i = 0;
        for (; i < a.keyParts.length - 1 && i < b.keyParts.length - 1; i++) {
          final c = a.keyParts[i].toLowerCase().compareTo(b.keyParts[i].toLowerCase());
          if (c != 0) return c;  // different parent nodes
        }
        // same parent nodes at level i-1
        final c = a.keyParts.length.compareTo(b.keyParts.length);
        if (c != 0) return c;  // mixed leafs/nodes at level i
        return a.keyParts[i].toLowerCase().compareTo(b.keyParts[i].toLowerCase());  // leafs at level i
      });
      final table = Table(
        columnWidths: const {
          0: IntrinsicColumnWidth(),  // unused-error-icon
          1: FlexColumnWidth(0.65),   // variant-id
          2: IntrinsicColumnWidth(),  // arrow
          3: FlexColumnWidth(0.35),   // value
          4: IntrinsicColumnWidth(),  // remove-button
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: entries.map((e) {
          return TableRow(
            children: [
              widget.variants[e.key]?.unused == true ?
                Tooltip(
                  message: "Not used by any installed package",
                  child: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                ) : const SizedBox(),
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
                      World.world.client.variantsReset([e.key], profileId: World.world.profile.id)  // we do not need to await result
                        .catchError(ApiErrorWidget.dialog);
                    });
                  },
                )),
              ),
            ],
          );
        }).toList(),
      );
      final unusedVariantIds = widget.variants.entries.where((e) => e.value.unused).map((e) => e.key).toList();
      return Column(
        children: [
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: table),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: unusedVariantIds.isEmpty ? null : () {
              setState(() {
                widget.variants.removeWhere((key, value) => value.unused);
                World.world.client.variantsReset(unusedVariantIds, profileId: World.world.profile.id)  // we do not need to await result
                  .catchError(ApiErrorWidget.dialog);
              });
            },
            child: const Text("Remove unused variants"),
          ),
          const SizedBox(height: 10),
        ],
      );
    }
  }
}

class ChannelsList extends StatefulWidget {
  const ChannelsList({super.key});
  @override State<ChannelsList> createState() => _ChannelsListState();
}
class _ChannelsListState extends State<ChannelsList> {
  late TextEditingController controller = TextEditingController();
  bool changed = false;

  @override void initState() {
    super.initState();
    _initText();
  }

  void _initText() async {
    controller.text = _stringifyUrls(await World.world.profile.dashboard.channelUrls);
  }

  List<String> _parseUrls(String text) => text.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();

  String _stringifyUrls(List<String> urls) => urls.isEmpty ? "" : "${urls.join('\n')}\n";

  void _submit(List<String> urls) {
    World.world.profile.dashboard.updateChannelUrls(urls)
      .then((_) {
        setState(() {
          _initText();
          changed = false;
        });
      },
      onError: ApiErrorWidget.dialog,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: listViewTextPadding,
            child: Text("Channels contain definitions for packages you can install."
              " Append additional channel URLs below. The first URL has the highest priority."),
          ),
        ),
        FutureBuilder(
          future: World.world.profile.dashboard.channelUrls,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: ApiErrorWidget(ApiError.from(snapshot.error!)));
            } else if (!snapshot.hasData) {
              return const SizedBox();
            } else {
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
                icon: const Icon(Symbols.layers_clear),
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

class PendingUpdatesWidget extends StatelessWidget {
  final Dashboard dashboard;
  const PendingUpdatesWidget(this.dashboard, {super.key});
  @override
  Widget build(BuildContext context) {
    final bool runningInBackground = dashboard.updateProcess?.status == UpdateStatus.running && dashboard.updateProcess?.isBackground == true;
    final int? count = runningInBackground ? null : dashboard.pendingUpdates.getCount();

    return ExpansionTile(
      leading: runningInBackground
        ? const SizedBox(width: 20, height: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)))
        : const Icon(Symbols.update),
      title: Text(["Pending updates", if (count != null) "($count)"].join(' ')),
      // expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: runningInBackground
        ? const [Padding(padding: listViewTextPadding, child: Text("Checking for updates..."))]
        : count == 0
        ? const [Padding(padding: listViewTextPadding, child: Text("No pending updates"))]
        : dashboard.pendingUpdates.sortedEntries().mapIndexed((index, entry) =>
          PackageTile(entry.key, index,
            pendingStatus: entry.value,
            refreshParent: () {},  // no refresh needed without toggle button
            visualDensity: const VisualDensity(vertical: VisualDensity.minimumDensity),
          )
        ).toList(),
    );
  }
}
