import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'dart:math';
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
  late final TextEditingController _searchBarController = TextEditingController(text: widget.myPlugins.searchTerm);
  // late Future<List<InstalledListItem>> searchResultFuture;
  // late Future<List<InstalledListItem>> filteredList;

  void _filter() {
    filteredList = searchResultFuture.then((searchResult) => searchResult.packages.where((pkg) =>
      widget.myPlugins.installStateSelection.contains(pkg.status.explicit ? InstallStateType.explicitlyInstalled : InstallStateType.installedAsDependency)
    ).toList());
  }

  void _search() {
    final q = widget.myPlugins.searchTerm;
    final c = widget.myPlugins.selectedCategory;
    searchResultFuture = Api.pluginsSearch(q ?? '', category: c, profileId: World.world.profile!.id);
    _filter();
  }
  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _searchBarController.dispose();
    super.dispose();
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
          // flexibleSpace: Placeholder(), // placeholder widget to visualize the shrinking size
          // expandedHeight: 200, // initial height of the SliverAppBar larger than normal
          toolbarHeight: _toolBarHeight,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
              const SizedBox(width: 20),
              Expanded(
                child: SearchBar(
                  controller: _searchBarController,
                  padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
                  leading: const Icon(Icons.search),
                  // or onChanged for immediate feedback?
                  onSubmitted: (String query) => setState(() {
                    widget.myPlugins.searchTerm = query;
                    _search();
                  }),
                  trailing: [
                    FutureBuilder<PluginsSearchResult>(
                      future: searchResultFuture,
                      builder: (context, snapshot) => Text((!snapshot.hasError && snapshot.hasData) ? '${snapshot.data!.packages.length} packages' : ''),
                    )
                  ],
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(_toolbarBottomHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SegmentedButton<InstallStateType>(
                  segments: const [
                    // ButtonSegment(value: InstallStateType.markedForInstall, label: Text('Pending'), icon: Icon(Icons.arrow_right)),
                    ButtonSegment(value: InstallStateType.explicitlyInstalled, label: Text('Explicitly installed'), icon: Icon(Icons.arrow_right)),
                    ButtonSegment(value: InstallStateType.installedAsDependency, label: Text('Installed as dependency'), icon: Icon(Icons.arrow_right)),
                  ],
                  multiSelectionEnabled: true,
                  selected: widget.myPlugins.installStateSelection,
                  onSelectionChanged: (Set<InstallStateType> newSelection) {
                    setState(() {
                      widget.myPlugins.installStateSelection = newSelection;
                      _filter();
                    });
                  },
                ),
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
                      subtitle: '${pkg.status.installed?.version} | ${pkg.summary} | ${pkg.status.timeLabel()}',
                      status: pkg.status,
                      onToggled: (checked) {
                        final task = checked ?
                            Api.add(module, profileId: World.world.profile!.id) :
                            Api.remove(module, profileId: World.world.profile!.id);
                        task.then((_) => _refresh(), onError: ApiErrorWidget.dialog);
                      },
                      chips: [
                        ...sortedVariantKeys.map((k) => PackageTileChip.variant(k, pkg.status.installed!.variant[k]!)),
                        // if (pkg.status.explicit) PackageTileChip.explicit(onDeleted: () {
                        //   Api.remove(module, profileId: World.world.profile!.id).then((_) {
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
