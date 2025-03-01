import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'dart:math';
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
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 5,
              children: <Widget>[
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
                SortMenu(
                  selected: widget.myPlugins.sortOrder,
                  onSelectionChanged: (newOrder) {
                  setState(() {
                    widget.myPlugins.sortOrder = newOrder;
                    _filter();
                  });
                }),
              ],
            ),
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
                    final module = BareModule.parse(pkg.package);
                    final sortedVariantKeys = pkg.status.installed?.variant.keys.toList() ?? [];
                    sortedVariantKeys.sort();
                    return PackageTile(
                      module,
                      index,
                      summary: pkg.summary,
                      status: pkg.status,
                      refreshParent: _refresh,
                      onToggled: (checked) => World.world.profile.dashboard.pendingUpdates.onToggledStarButton(module, checked, refreshParent: _refresh),
                      chips: [
                        ...sortedVariantKeys.map((k) => PackageTileChip.variant(k, pkg.status.installed!.variant[k]!)),
                        // if (pkg.status.explicit) PackageTileChip.explicit(onDeleted: () {
                        //   World.world.client.remove(module, profileId: World.world.profile.id).then((_) {
                        //     _refresh();
                        //   }, onError: ApiErrorWidget.dialog);  // TODO handle failure and success
                        // }),
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
