import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:file_picker/file_picker.dart' show FilePicker, FileType, FilePickerResult;
import 'dart:typed_data' show Uint8List;
import 'dart:math';
import 'dart:ui' show PointerDeviceKind;
import 'dart:convert';
import 'dart:collection' show LinkedHashMap;
import 'package:collection/collection.dart' show mergeSort;
import 'package:badges/badges.dart' as badges;
import '../data.dart';
import '../model.dart';
import '../viewmodel.dart';
import 'fragments.dart';

class MyPluginsScreen extends StatefulWidget {
  final MyPlugins myPlugins;
  const MyPluginsScreen(this.myPlugins, {super.key});

  @override
  State<MyPluginsScreen> createState() => _MyPluginsScreenState();
}
class _MyPluginsScreenState extends State<MyPluginsScreen> {
  late Future<PluginsSearchResult> searchResultFuture;
  late Future<List<PluginsSearchResultItem>> filteredList;
  // late Future<List<InstalledListItem>> searchResultFuture;
  // late Future<List<InstalledListItem>> filteredList;

  static int _compareDates(DateTime? t1, DateTime? t2) {
    // null dates are sorted to the front, recent dates to the back
    if (t2 != null) {
      return t1?.compareTo(t2) ?? -1;
    } else {
      return t1 != null ? 1 : 0;
    }
  }

  void _filter() {
    filteredList = searchResultFuture.then((searchResult) {
      final pkgs = searchResult.packages.where((pkg) =>
        widget.myPlugins.installStateSelection.contains(pkg.status.explicit ? InstallStateType.explicitlyInstalled : InstallStateType.installedAsDependency)
      ).toList();
      switch (widget.myPlugins.sortOrder) {
        case SortOrder.relevance:
          break;  // use default order as returned by Api
        case SortOrder.installed:
          // stable sort
          mergeSort(pkgs, compare: (pkg1, pkg2) => _compareDates(pkg2.status.installed?.installedAt, pkg1.status.installed?.installedAt));
          break;
        case SortOrder.updated:
          // stable sort
          mergeSort(pkgs, compare: (pkg1, pkg2) => _compareDates(pkg2.status.installed?.updatedAt, pkg1.status.installed?.updatedAt));
          break;
      }
      return pkgs;
    });
  }

  // TODO turn MyPlugins into ChangeNotifier and move _search there (similarly to how FindPackages is set up)
  void _search() {
    final q = widget.myPlugins.searchTerm;
    final c = widget.myPlugins.selectedCategory;
    searchResultFuture = World.world.client.pluginsSearch(q ?? '', category: c, profileId: World.world.profile.id);
    _filter();
  }
  @override
  void initState() {
    super.initState();
    _search();
  }

  void _refresh() {
    setState(() {
      _search();
    });
  }

  static const double _toolBarHeight = 100.0;
  static const double _toolbarBottomHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          // pinned: true,  // TODO consider pinning to avoid scroll physics auto-scrolling to top when touching app bar
          // flexibleSpace: Placeholder(), // placeholder widget to visualize the shrinking size
          // expandedHeight: 200, // initial height of the SliverAppBar larger than normal
          toolbarHeight: _toolBarHeight,
          title: Table(
            columnWidths: const {
              0: MinColumnWidth(FixedColumnWidth(CategoryMenu.width), FractionColumnWidth(0.33)),
              1: FixedColumnWidth(20),  // padding
              2: FlexColumnWidth(1),  // takes up remaining space
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [TableRow(
              children: <Widget>[
                FutureBuilder(
                  future: searchResultFuture.then((searchResult) => searchResult.stats),
                  builder: (context, snapshot) {
                    // if snapshot.hasError, this usually means /error/channels-not-available which can be ignored here
                    return CategoryMenu(
                      stats: snapshot.data,  // possibly null
                      initialCategory: widget.myPlugins.selectedCategory,
                      menuHeight: max(300,
                        MediaQuery.of(context).size.height - _toolBarHeight
                        - MediaQuery.of(context).viewInsets.bottom,  // e.g. on-screen keyboard height
                      ),
                      onSelected: (s) {
                        setState(() {
                          widget.myPlugins.selectedCategory = s;
                          _search();
                        });
                      },
                    );
                  },
                ),
                const SizedBox(),
                PackageSearchBar(
                  initialText: widget.myPlugins.searchTerm,
                  onSubmitted: (String query) => setState(() {
                    widget.myPlugins.searchTerm = query;
                    _search();
                  }),
                  onCanceled: () => setState(() {
                    widget.myPlugins.searchTerm = '';
                    _search();
                  }),
                  resultsCount: searchResultFuture.then((data) => data.packages.length),
                ),
              ],
            )],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(_toolbarBottomHeight),
            child:
              switch(<Widget>[
                Padding(padding: const EdgeInsets.only(bottom: 5), child: SegmentedButton<InstallStateType>(
                  segments: [
                    // ButtonSegment(value: InstallStateType.markedForInstall, label: Text('Pending'), icon: Icon(Icons.arrow_right)),
                    ButtonSegment(
                      value: InstallStateType.explicitlyInstalled,
                      label: const Text("Stars"),
                      tooltip: "Explicitly installed packages",
                      icon: InstalledStatusIconExplicit(
                        badgeColor: Theme.of(context).segmentedButtonTheme.style?.backgroundColor?.resolve(
                          widget.myPlugins.installStateSelection.contains(InstallStateType.explicitlyInstalled) ? {WidgetState.selected} : {}
                        ),
                        badgeScale: 0.75,
                      ),
                    ),
                    const ButtonSegment(
                      value: InstallStateType.installedAsDependency,
                      label: Text("Dependencies"),
                      tooltip: "Packages installed as dependency",
                      icon: InstalledStatusIconDependency(),
                    ),
                  ],
                  showSelectedIcon: false,
                  multiSelectionEnabled: true,
                  selected: widget.myPlugins.installStateSelection,
                  onSelectionChanged: (Set<InstallStateType> newSelection) {
                    setState(() {
                      widget.myPlugins.installStateSelection = newSelection;
                      _filter();
                    });
                  },
                )),
                const SizedBox(width: 15),
                SortMenu(
                  selected: widget.myPlugins.sortOrder,
                  onSelectionChanged: (newOrder) {
                  setState(() {
                    widget.myPlugins.sortOrder = newOrder;
                    _filter();
                  });
                }),
                const SizedBox(width: 15),
                ...switch (TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant)) {
                  final textButtonStyle => [
                    TextButton.icon(
                      icon: const Icon(Symbols.download),
                      label: const Text("Import"),
                      style: textButtonStyle,
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: true,
                          builder: (context) => const ImportDialog(),
                        );
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Symbols.upload),
                      label: const Text("Export"),
                      style: textButtonStyle,
                      onPressed: () {
                        final dataFuture = filteredList
                          .then((searchedItems) async {
                            final modules = [for (final item in searchedItems) if (item.status.explicit == true) item.package];
                            final ExportData data = await World.world.client.export(modules, profileId: World.world.profile.id)  // somewhat expensive due to resolving (which requires parsing package files)
                              .catchError((Object e) async {
                                await ApiErrorWidget.dialog(e);
                                // as fallback, use all variants and channels
                                final variants = (await World.world.profile.dashboard.variantsFuture).variants;
                                final channels = await World.world.profile.dashboard.channelUrls;
                                return ExportData(
                                  explicit: modules,
                                  variants: {for (final item in variants.entries) if (!item.value.unused) item.key: item.value.value},
                                  channels: channels,
                                );
                              });
                            final variantEntries = data.variants?.entries.toList();
                            if (variantEntries != null) {
                              Dashboard.sortVariants(variantEntries, keyParts: (e) => e.key.split(':'));
                              data.variants = LinkedHashMap.fromEntries(variantEntries);  // preserves insertion order
                            }
                            return data;
                          });
                        showDialog(
                          context: context,
                          barrierDismissible: true,
                          builder: (context) => ExportDialog(dataFuture),
                        );
                      },
                    ),
                  ],
                },
              ]) {
                final toolbarBottomWidgets =>
                  ScrollConfiguration(
                    behavior: switch (ScrollConfiguration.of(context)) {
                      final behavior => behavior.copyWith(dragDevices: {PointerDeviceKind.mouse, ...behavior.dragDevices}),  // enable click-drag for horizontal scrolling
                    },
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: toolbarBottomWidgets,
                      ),
                    ),
                  )
              },
          ),
        ),
        FutureBuilder<List<PluginsSearchResultItem>>(
          future: filteredList,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SliverToBoxAdapter(child: Center(child: ApiErrorWidget(ApiError.from(snapshot.error!))));
            } else if (!snapshot.hasData) {
              return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
            } else if (snapshot.data!.isEmpty) {
              return const SliverToBoxAdapter(child: ListTile(leading: Icon(Icons.search_off), title: Text("No plugins.")));
            } else {
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final pkg = snapshot.data![index];
                    final sortedVariantKeys = pkg.status.installed?.variant.keys.toList() ?? [];
                    sortedVariantKeys.sort();
                    return PackageTile(
                      pkg.module,
                      index,
                      summary: pkg.summary,
                      status: pkg.status,
                      refreshParent: _refresh,
                      onToggled: (checked) => World.world.profile.dashboard.pendingUpdates.onToggledStarButton(pkg.module, checked).then((_) => _refresh()),
                      chips: [
                        ...sortedVariantKeys.map((k) => PackageTileChip.variant(k, pkg.status.installed!.variant[k]!, pkg.module)),
                      ],
                    );
                  },
                  childCount: snapshot.data!.length,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

class ExportDialog extends StatefulWidget {
  final Future<ExportData> dataFuture;
  const ExportDialog(this.dataFuture, {super.key});
  @override State<ExportDialog> createState() => _ExportDialogState();
}
class _ExportDialogState extends State<ExportDialog> {
  late final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Symbols.download),
      title: const Text('Export a Mod Set'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 720),
        child:
        Column(
          mainAxisSize: MainAxisSize.max,  // so that height stays fixed when progress indicator is displayed
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Text("A Mod Set is a selection of packages, encoded in JSON format. Copy the JSON contents below to share the Mod Set."),
            const SizedBox(height: 10),
            Expanded(
              child: SizedBox(
                width: ExportDialogTextField.maxWidth,
                child: FutureBuilder(
                  future: widget.dataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError || !snapshot.hasData) {
                      return snapshot.hasError
                        ? ApiErrorWidget.scroll(ApiError.from(snapshot.error!))
                        : const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 60), child: CircularProgressIndicator()));
                    } else {
                      _controller.text = jsonUtf8EncodeIndented(snapshot.data);
                      return ExportDialogTextField(
                        controller: _controller,
                        autovalidate: true,
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FutureBuilder(
          future: widget.dataFuture,
          builder: (context, snapshot) =>
            Tooltip(
              message: "Copy to clipboard",
              child: TextButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text("Copy"),
                onPressed: !snapshot.hasData ? null : () => Clipboard.setData(ClipboardData(text: _controller.text))
              ),
            ),
        ),
        FutureBuilder(
          future: widget.dataFuture,
          builder: (context, snapshot) =>
            TextButton.icon(
              icon: const Icon(Symbols.file_export),
              label: const Text("Save as JSON file"),
              onPressed: !snapshot.hasData ? null : () async {
                final Uint8List fileBytes = const Utf8Encoder().convert(_controller.text);
                debugPrint("file size: ${fileBytes.length}");
                final String? file = await FilePicker.platform.saveFile(
                  dialogTitle: 'Please select an output file:',
                  fileName: 'my-modset.sc4pac.json',
                  type: FileType.custom,
                  allowedExtensions: ['json'],
                  bytes: fileBytes,
                );
                debugPrint(file == null ? "Save-File dialog canceled" : "File saved: $file");
              },
            ),
        ),
        const SizedBox(width: 80),
        OutlinedButton(
          onPressed: () { Navigator.pop(context, null); },
          child: const Text("Dismiss"),
        ),
      ],
    );
  }
}

class ImportDialog extends StatefulWidget {
  const ImportDialog({super.key});
  @override State<ImportDialog> createState() => _ImportDialogState();
}
class _ImportDialogState extends State<ImportDialog> {
  late final _controller = TextEditingController();
  static final _hintText = jsonUtf8EncodeIndented(ExportData(explicit: ["memo:submenus-dll", "memo:3d-camera-dll"]).toJson());
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ExportData? _validate() =>
    ExportDialogTextField.validate(
      _controller.text,
      handleError: (errMsg) => setState(() { _errorText = errMsg; }),
    );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Symbols.download),
      title: const Text('Import a Mod Set'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 720),
        child:
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("A Mod Set is a selection of packages, encoded in JSON format. Paste the JSON contents here or load a file to import the packages."),
            const SizedBox(height: 10),
            TextButton.icon(
              icon: const Icon(Symbols.file_open),
              label: const Text('Open JSON file'),
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  allowMultiple: false,
                  type: FileType.custom,
                  allowedExtensions: ['json'],
                  withData: true,  // initializes fileBytes
                );
                if (result != null) {
                  final fileBytes = result.files.first.bytes;
                  if (fileBytes != null) {
                    _controller.text = const Utf8Decoder(allowMalformed: true).convert(fileBytes);
                    _validate();
                  } else {
                    ApiErrorWidget.dialog(ApiError.unexpected("Loading files is not supported on this platform.", ""));
                  }
                }
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SizedBox(
                width: ExportDialogTextField.maxWidth,
                child: ExportDialogTextField(
                  controller: _controller,
                  hintText: _hintText,
                  errorText: _errorText,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        ListenableBuilder(
          listenable: _controller,
          builder: (context, child) => FilledButton(
            onPressed: _controller.text.trim().isEmpty ? null : () {
              final data = _validate();
              if (data != null) {
                Navigator.pop(context, null);
                World.world.profile.myPlugins.import(data);
              }
            },
            child: child,
          ),
          child: const Text("OK"),
        ),
        OutlinedButton(
          onPressed: () { Navigator.pop(context, null); },
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}

class ExportDialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final String? errorText;
  final bool autovalidate;
  const ExportDialogTextField({required this.controller, this.hintText, this.errorText, this.autovalidate = false, super.key})
      : assert(errorText == null || !autovalidate);  // don't use errorText and autovalidate simultaneously

  static const double maxWidth = 960;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
          controller: controller,
          minLines: 100,
          keyboardType: TextInputType.multiline,
          maxLines: null,
          decoration: InputDecoration(
            hintText: hintText,
            errorText: !autovalidate ? errorText : null,
            errorStyle: const TextStyle(fontFamily: 'monospace'),
          ),
          autovalidateMode: !autovalidate ? null : AutovalidateMode.onUserInteraction,
          validator: !autovalidate ? null : (text) {
            String? errMsg;
            if (text != null) {
              validate(text, handleError: (e) { errMsg = e; });
            }
            return errMsg;
          },
    );
  }

  static ExportData? validate(String text, {required void Function(String? error) handleError}) {
    ExportData? data;
    String? errMsg;
    try {
      if (text.trim().isNotEmpty) {
        data = ExportData.fromJson(jsonDecode(text) as Map<String, dynamic>);
      }
    } catch (e) {
      errMsg = e.toString();
    }
    handleError(errMsg);
    return data;
  }
}

class SortMenu extends StatefulWidget {
  final SortOrder selected;  // initial value
  final void Function(SortOrder) onSelectionChanged;
  const SortMenu({required this.selected, required this.onSelectionChanged, super.key});
  @override State<SortMenu> createState() => _SortMenuState();
}

class _SortMenuState extends State<SortMenu> {
  late SortOrder _sortOrder = widget.selected;

  static const _sortSymbol = {
    SortOrder.relevance: Symbols.sort_by_alpha,
    SortOrder.updated: Icons.update,
    SortOrder.installed: Symbols.playlist_add
  };

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (BuildContext context, MenuController controller, Widget? child) {
        return IconButton(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: badges.Badge(
            badgeContent: Icon(_sortSymbol[_sortOrder], size: 16),
            position: badges.BadgePosition.bottomEnd(bottom: -3, end: -6),
            badgeAnimation: const badges.BadgeAnimation.scale(),
            badgeStyle: badges.BadgeStyle(
              padding: const EdgeInsets.all(1.2),
              badgeColor: Theme.of(context).colorScheme.surface,
            ),
            child: const Icon(Symbols.sort),
          ),
          tooltip: 'Sort',
        );
      },
      menuChildren: List<MenuItemButton>.generate(
        SortOrder.values.length,
        (int index) {
          final newOrder = SortOrder.values[index];
          return MenuItemButton(
            onPressed: () {
              if (_sortOrder != newOrder) {
                setState(() => _sortOrder = newOrder);
                widget.onSelectionChanged(newOrder);
              }
            },
            leadingIcon: Icon(_sortSymbol[newOrder], color: _sortOrder == newOrder ? Theme.of(context).primaryColor : null),
            child: Text(
              switch (newOrder) { SortOrder.relevance => "Relevance", SortOrder.updated => "Updated recently", SortOrder.installed => "Installed recently" },
              style: _sortOrder == newOrder ? DefaultTextStyle.of(context).style.copyWith(color: Theme.of(context).primaryColor) : null,
            ),
          );
        }
      ),
    );
  }
}
