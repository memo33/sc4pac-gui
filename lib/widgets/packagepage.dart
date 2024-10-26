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

  static Future<dynamic> pushPkg(BuildContext context, BareModule module) {
    return Navigator.push(
      context,
      MaterialPageRoute(barrierDismissible: true, builder: (context1) => PackagePage(module)),
    );
  }
}
class _PackagePageState extends State<PackagePage> {
  late Future<PackageInfoResult> futureJson;

  static TableRow packageTableRow(String label, Widget child) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(10, 5, 20, 5), child: Text(label)),
        Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: child),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchInfo();
  }

  void _fetchInfo() {
    futureJson = Api.info(widget.module, profileId: World.world.profile!.id);
  }

  void _refresh() {
    setState(_fetchInfo);  // TODO refetching not necessarily needed on this page, but on previous page
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CopyButton(
          copyableText: widget.module.toString(),
          child: PkgNameFragment(widget.module, asButton: false, colored: false),
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
            bool addedExplicitly = statuses[widget.module.toString()]?.explicit ?? false;

            return LayoutBuilder(builder: (context, constraint) =>
              SingleChildScrollView(child: Align(alignment: const Alignment(-0.75, 0), child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraint.maxHeight, maxWidth: 600),
                child: IntrinsicHeight(
                  child: Table(
                    columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
                    children: <TableRow>[
                      packageTableRow("", AddPackageButton(widget.module, addedExplicitly, refreshParent: _refresh)),  // TODO positioning
                      packageTableRow("Version", Text(switch (remote) { {'version': String v} => v, _ => 'Unknown' })),
                      if (remote case {'info': dynamic info})
                        packageTableRow("Summary", switch (info) { {'summary': String text} => MarkdownText(text), _ => const Text('-') }),
                      if (remote case {'info': {'description': String text}})
                        packageTableRow("Description", MarkdownText(text)),
                      if (remote case {'info': {'warning': String text}})
                        packageTableRow("Warning", MarkdownText(text)),
                      if (remote case {'info': dynamic info})
                        packageTableRow("Conflicts", switch (info) { {'conflicts': String text} => MarkdownText(text), _ => const Text('None') }),
                      if (remote case {'info': {'author': String text}})
                        packageTableRow("Author", Text(text)),
                      if (remote case {'info': {'website': String text}})
                        packageTableRow("Website", CopyButton(copyableText: text, child: Hyperlink(url: text))),
                      packageTableRow("Subfolder", Text(switch (remote) { {'subfolder': String v} => v, _ => 'Unknown' })),
                      packageTableRow("Variants",
                        variants.isEmpty || variants.length == 1 && variants[0].isEmpty ? const Text('None') : Wrap(
                          direction: Axis.vertical,
                          spacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.start,
                          children: variants.map((vs) => Wrap(spacing: 5, children: vs.map((v) =>
                            PackageTileChip.variant(v.label, v.value, description: v.desc),
                          ).toList())).toList()
                        )
                      ),
                      packageTableRow("Dependenies",
                        dependencies.isEmpty ? const Text('None') : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: dependencies.map((module) => PkgNameFragment(module, asButton: true, status: statuses[module.toString()])).toList(),
                        )
                      ),
                      packageTableRow("Required By",
                        requiredBy.isEmpty ? const Text('None') : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: requiredBy.map((module) => PkgNameFragment(module, asButton: true, status: statuses[module.toString()])).toList(),
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
          final task = _addedExplicitly ?
              Api.add(widget.module, profileId: World.world.profile!.id) :
              Api.remove(widget.module, profileId: World.world.profile!.id);
          task.then((_) => widget.refreshParent()).catchError(ApiErrorWidget.dialog);  // async, but we do not need to await result
        });
      },
    );
  }
}
