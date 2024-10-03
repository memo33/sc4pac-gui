import 'dart:collection' show LinkedHashSet;
import 'package:flutter/material.dart';
import '../model.dart';
import 'fragments.dart';

class PackagePage extends StatefulWidget {
  final BareModule module;
  const PackagePage(this.module, {super.key});

  @override
  State<PackagePage> createState() => _PackagePageState();

  static Future<dynamic> pushPkg(BuildContext context, BareModule module) {
    return Navigator.push(
      context,
      MaterialPageRoute(barrierDismissible: true, builder: (context) => PackagePage(module)),
    );
  }
}
class _PackagePageState extends State<PackagePage> {
  late Future<Map<String, dynamic>> futureJson;

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
    futureJson = Api.info(widget.module);  // TODO
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
      body: FutureBuilder<Map<String, dynamic>>(
        future: futureJson,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: ApiErrorWidget(ApiError.from(snapshot.error!)));
          } else if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          } else {
            final dependencies = LinkedHashSet<BareModule>.from(switch (snapshot.data) {
              {'variants': List<dynamic> variants} =>
                variants.expand((variant) => switch (variant) {
                  {'dependencies': List<dynamic> deps} =>
                    deps.expand((dep) => [if (dep case {'group': String group, 'name': String name}) BareModule(group, name)]),
                  _ => <BareModule>[]
                }),
              _ => <BareModule>[]
            });
            final Iterable<BareModule> requiredBy = switch (snapshot.data) {
              {'info': {'requiredBy': List<dynamic> mods }} =>
                mods.map((s) => BareModule.parse(s as String)).whereType<BareModule>(),
              _ => <BareModule>[]
            };
            final Map<String, Map<String, String>> descriptions = switch (snapshot.data) {
              {'variantDescriptions': Map<String, dynamic> descs} =>
                descs.map((label, values) => MapEntry(label, (values as Map<String, dynamic>).cast<String, String>())),
              _ => {},
            };
            final List<Iterable<({String label, String value, String? desc})>> variants = switch (snapshot.data) {
              {'variants': List<dynamic> vds} =>
                vds.map((vd) => switch (vd) {
                  {'variant': Map<String, dynamic> variant} =>
                    variant.entries.map<({String label, String value, String? desc})>((e) => (label: e.key, value: e.value, desc: descriptions[e.key]?[e.value])),
                  _ => <({String label, String value, String? desc})>[]
                }).toList(),
              _ => []
            };
            bool addedExplicitly = false; // TODO compute this or change api

            return LayoutBuilder(builder: (context, constraint) =>
              SingleChildScrollView(child: Align(alignment: const Alignment(-0.75, 0), child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraint.maxHeight, maxWidth: 600),
                child: IntrinsicHeight(
                  child: Table(
                    columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
                    children: <TableRow>[
                      packageTableRow("", AddPackageButton(widget.module, addedExplicitly)),  // TODO positioning
                      packageTableRow("Version", Text(switch (snapshot.data) { {'version': String v} => v, _ => 'Unknown' })),
                      if (snapshot.data case {'info': dynamic info})
                        packageTableRow("Summary", switch (info) { {'summary': String text} => MarkdownText(text), _ => const Text('-') }),
                      if (snapshot.data case {'info': {'description': String text}})
                        packageTableRow("Description", MarkdownText(text)),
                      if (snapshot.data case {'info': {'warning': String text}})
                        packageTableRow("Warning", MarkdownText(text)),
                      if (snapshot.data case {'info': dynamic info})
                        packageTableRow("Conflicts", switch (info) { {'conflicts': String text} => MarkdownText(text), _ => const Text('None') }),
                      if (snapshot.data case {'info': {'author': String text}})
                        packageTableRow("Author", Text(text)),
                      if (snapshot.data case {'info': {'website': String text}})
                        packageTableRow("Website", CopyButton(copyableText: text, child: Hyperlink(url: text))),
                      packageTableRow("Subfolder", Text(switch (snapshot.data) { {'subfolder': String v} => v, _ => 'Unknown' })),
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
                          children: dependencies.map((module) => PkgNameFragment(module, asButton: true, isInstalled: true)).toList(),  // TODO
                        )
                      ),
                      packageTableRow("Required By",
                        requiredBy.isEmpty ? const Text('None') : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: requiredBy.map((module) => PkgNameFragment(module, asButton: true, isInstalled: true)).toList(),  // TODO
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
  //bool isInstalled;
  const AddPackageButton(this.module, this.initialAddedExplicitly, {super.key});

  @override
  State<AddPackageButton> createState() => _AddPackageButtonState();
}
class _AddPackageButtonState extends State<AddPackageButton> {
  late bool addedExplicitly;

  @override
  void initState() {
    super.initState();
    addedExplicitly = widget.initialAddedExplicitly;  // TODO
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(  // TODO use toggle button?
      icon: Icon(addedExplicitly ? /*Icons.more_time*/ Icons.add_task : Icons.add),
      label: Text(addedExplicitly ? "Remove from Plugins" : "Add to Plugins"),
      onPressed: () {
        setState(() { addedExplicitly = !addedExplicitly; });
        Api.add(widget.module);  // async, but we do not need to await result (TODO maybe we should to avoid race?)
      },
    );
  }
}
