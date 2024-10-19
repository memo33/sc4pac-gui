import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
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
  late Future<List<InstalledListItem>> futureJson;
  late Future<List<InstalledListItem>> filteredList;

  void _computeFilter() {
    filteredList = futureJson.then((items) => items.where((pkg) =>
      widget.myPlugins.installStateSelection.contains(pkg.explicit ? InstallStateType.explicitlyInstalled : InstallStateType.installedAsDependency)
    ).toList());
  }

  void _computeState() {
    futureJson = Api.installed(profileId: World.world.profile!.id);
    _computeFilter();
  }

  @override
  void initState() {
    super.initState();
    _computeState();
  }

  void refresh() {
    setState(() {
      _computeState();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          bottom: PreferredSize(preferredSize: const Size.fromHeight(180.0), child: Column(  // TODO avoid setting explicit size
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 10),
              SearchBar(
                padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
                leading: const Icon(Icons.search),
                // or onChanged for immediate feedback?
                onSubmitted: (String query) => setState(() { }),  // TODO
                // trailing: [
                //   FutureBuilder<List<Map<String, dynamic>>>(
                //     future: filteredList,
                //     builder: (context, snapshot) => Text((!snapshot.hasError && snapshot.hasData) ? '${snapshot.data!.length} packages' : ''),
                //   )
                // ],
              ),
              const SizedBox(height: 20),
              const DropdownMenu<String>(
                width: 400,
                leadingIcon: Icon(Symbols.category_search),
                //initialSelection: '',
                label: Text('Category'),
                dropdownMenuEntries: [
                  DropdownMenuEntry<String>(
                    value: '',
                    label: 'All',
                  ),
                  DropdownMenuEntry<String>(
                    value: '150-mods',
                    label: '150-mods',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SegmentedButton<InstallStateType>(
                segments: const [
                  ButtonSegment(value: InstallStateType.markedForInstall, label: Text('Pending'), icon: Icon(Icons.arrow_right)),
                  ButtonSegment(value: InstallStateType.explicitlyInstalled, label: Text('Explicitly installed'), icon: Icon(Icons.arrow_right)),
                  ButtonSegment(value: InstallStateType.installedAsDependency, label: Text('Installed as dependency'), icon: Icon(Icons.arrow_right)),
                ],
                multiSelectionEnabled: true,
                selected: widget.myPlugins.installStateSelection,
                onSelectionChanged: (Set<InstallStateType> newSelection) {
                  setState(() {
                    widget.myPlugins.installStateSelection = newSelection;
                    _computeFilter();
                  });
                },
              ),
            ],
          )),
        ),
        FutureBuilder<List<InstalledListItem>>(
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
                    final sortedVariantKeys = pkg.variant.keys.toList();
                    sortedVariantKeys.sort();
                    return PackageTile(
                      module,
                      index,
                      subtitle: '${pkg.version} | summary…',
                      chips: [
                        ...sortedVariantKeys.map((k) => PackageTileChip.variant(k, pkg.variant[k]!)),
                        if (pkg.explicit) PackageTileChip.explicit(onDeleted: () {
                          Api.remove(module, profileId: World.world.profile!.id).then((_) {
                            refresh();
                          }, onError: ApiErrorWidget.dialog);  // TODO handle failure and success
                        }),
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
