import 'dart:collection' show LinkedHashSet;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '../model.dart';
import '../viewmodel.dart';
import 'fragments.dart';
import '../data.dart';

class PackagePage extends StatefulWidget {
  final BareModule module;
  const PackagePage(this.module, {super.key});

  @override
  State<PackagePage> createState() => _PackagePageState();

  static Future<dynamic> pushPkg(BuildContext context, BareModule module, {required void Function() refreshPreviousPage}) {
    return Navigator.push(
      context,
      MaterialPageRoute(barrierDismissible: true, builder: (context1) => PackagePage(module)),
    ).then((_) => refreshPreviousPage());
  }
}
class _PackagePageState extends State<PackagePage> {
  late Future<PackageInfoResult> futureJson;

  static TableRow packageTableRow(Widget? label, Widget child) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 5, 20, 5),
          child: label ?? const SizedBox(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: child,
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchInfo();
  }

  void _fetchInfo() {
    futureJson = World.world.client.info(widget.module, profileId: World.world.profile!.id);
  }

  void _refresh() {
    setState(_fetchInfo);
  }

  @override
  Widget build(BuildContext context) {
    final moduleStr = widget.module.toString();
    return Scaffold(
      appBar: AppBar(
        title: CopyButton(
          copyableText: moduleStr,
          child: PkgNameFragment(widget.module, asButton: false, colored: false, refreshParent: _refresh),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.close), tooltip: 'Close all', onPressed: () {
            Navigator.popUntil(context, ModalRoute.withName('/'));
          }),
        ],
      ),
      body: FutureBuilder<PackageInfoResult>(
        future: futureJson,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: ApiErrorWidget(ApiError.from(snapshot.error!)));
          } else if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          } else {
            final remote = snapshot.data!.remote;
            final statuses = snapshot.data!.local.statuses;
            final dependencies = LinkedHashSet<BareModule>.from(switch (remote) {
              {'variants': List<dynamic> variants} =>
                variants.expand((variant) => switch (variant) {
                  {'dependencies': List<dynamic> deps} =>
                    deps.expand((dep) => [if (dep case {'group': String group, 'name': String name}) BareModule(group, name)]),
                  _ => <BareModule>[]
                }),
              _ => <BareModule>[]
            });
            final Iterable<BareModule> requiredBy = switch (remote) {
              {'info': {'requiredBy': List<dynamic> mods }} =>
                mods.map((s) => BareModule.parse(s as String)).whereType<BareModule>(),
              _ => <BareModule>[]
            };
            final Map<String, Map<String, String>> descriptions = switch (remote) {
              {'variantDescriptions': Map<String, dynamic> descs} =>
                descs.map((label, values) => MapEntry(label, (values as Map<String, dynamic>).cast<String, String>())),
              _ => {},
            };
            final List<Iterable<({String label, String value, String? desc})>> variants = switch (remote) {
              {'variants': List<dynamic> vds} =>
                vds.map((vd) => switch (vd) {
                  {'variant': Map<String, dynamic> variant} =>
                    variant.entries.map<({String label, String value, String? desc})>((e) => (label: e.key, value: e.value, desc: descriptions[e.key]?[e.value])),
                  _ => <({String label, String value, String? desc})>[]
                }).toList(),
              _ => []
            };
            final status = statuses[moduleStr];
            bool addedExplicitly = status?.explicit ?? false;
            final installDates = status?.timeLabel2() ?? "Not installed";
            final installedVersion = status?.installed?.version;

            return LayoutBuilder(builder: (context, constraint) =>
              SingleChildScrollView(child: Align(alignment: const Alignment(-0.75, 0), child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraint.maxHeight, maxWidth: 600),
                child: IntrinsicHeight(
                  child: Table(
                    columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
                    children: <TableRow>[
                      packageTableRow(null, AddPackageButton(widget.module, addedExplicitly, refreshParent: _refresh)),  // TODO positioning
                      packageTableRow(Align(alignment:Alignment.centerLeft, child: InstalledStatusIcon(status)), Text(installDates)),
                      packageTableRow(const Text("Version"), Text(switch (remote) {
                        {'version': String v} => installedVersion != null && installedVersion != v ? "$v (currently installed: $installedVersion)" : v,
                        _ => 'Unknown'
                      })),
                      if (remote case {'info': dynamic info})
                        packageTableRow(const Text("Summary"), switch (info) { {'summary': String text} => MarkdownText(text), _ => const Text('-') }),
                      if (remote case {'info': {'description': String text}})
                        packageTableRow(const Text("Description"), MarkdownText(text)),
                      if (remote case {'info': {'warning': String text}})
                        packageTableRow(const Text("Warning"), MarkdownText(text)),
                      if (remote case {'info': dynamic info})
                        packageTableRow(const Text("Conflicts"), switch (info) { {'conflicts': String text} => MarkdownText(text), _ => const Text('None') }),
                      if (remote case {'info': {'author': String text}})
                        packageTableRow(const Text("Author"), Text(text)),
                      if (remote case {'info': {'website': String text}})
                        packageTableRow(const Text("Website"), CopyButton(copyableText: text, child: Hyperlink(url: text))),
                      packageTableRow(const Text("Subfolder"), Text(switch (remote) { {'subfolder': String v} => v, _ => 'Unknown' })),
                      packageTableRow(const Text("Variants"),
                        variants.isEmpty || variants.length == 1 && variants[0].isEmpty ? const Text('None') : Wrap(
                          direction: Axis.vertical,
                          spacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.start,
                          children: variants.map((vs) => Wrap(spacing: 5, children: vs.map((v) =>
                            PackageTileChip.variant(v.label, v.value, description: v.desc),
                          ).toList())).toList()
                        )
                      ),
                      packageTableRow(const Text("Dependenies"),
                        dependencies.isEmpty ? const Text('None') : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: dependencies.map((module) => PkgNameFragment(module, asButton: true, refreshParent: _refresh, status: statuses[module.toString()])).toList(),
                        )
                      ),
                      packageTableRow(const Text("Required By"),
                        requiredBy.isEmpty ? const Text('None') : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: requiredBy.map((module) => PkgNameFragment(module, asButton: true, refreshParent: _refresh, status: statuses[module.toString()])).toList(),
                        )
                      ),
                    ],
                  ),
                ),
              ))),
            );
          }
        }
      ),
    );
  }
}

class AddPackageButton extends StatefulWidget {
  final BareModule module;
  final bool initialAddedExplicitly;
  final void Function() refreshParent;
  //bool isInstalled;
  const AddPackageButton(this.module, this.initialAddedExplicitly, {required this.refreshParent, super.key});

  @override
  State<AddPackageButton> createState() => _AddPackageButtonState();
}
class _AddPackageButtonState extends State<AddPackageButton> {
  late bool _addedExplicitly = widget.initialAddedExplicitly;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      icon: Icon(Symbols.star, fill: _addedExplicitly ? 1 : 0),
      label: Text(_addedExplicitly ? "Added to Plugins explicitly" : "Add to Plugins explicitly"),
      onPressed: () {
        setState(() {
          _addedExplicitly = !_addedExplicitly;
          World.world.profile!.dashboard.onToggledStarButton(widget.module, _addedExplicitly, refreshParent: widget.refreshParent);
        });
      },
    );
  }
}
