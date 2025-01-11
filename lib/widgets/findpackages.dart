import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'dart:math';
import '../data.dart';
import '../model.dart';
import '../viewmodel.dart';
import 'fragments.dart';

class FindPackagesScreen extends StatelessWidget {
  final FindPackages findPackages;
  const FindPackagesScreen(this.findPackages, {super.key});

  static const double _toolBarHeight = 100.0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: findPackages,
      builder: (context, child) => CustomScrollView(slivers: [
        SliverAppBar(
          floating: true,
          // pinned: true,  // TODO consider pinning to avoid scroll physics auto-scrolling to top when touching app bar
          // flexibleSpace: Placeholder(), // placeholder widget to visualize the shrinking size
          // expandedHeight: 200, // initial height of the SliverAppBar larger than normal
          toolbarHeight: _toolBarHeight,
          title: findPackages.customFilter != null
            ? InputChip(
              label: const Text("Custom package filter"),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
              onDeleted: () {
                findPackages.updateCustomFilter(null);
              },
            )
            : Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FixedColumnWidth(10),  // padding
              2: MinColumnWidth(FixedColumnWidth(CategoryMenu.width), FractionColumnWidth(0.33)),
              3: FixedColumnWidth(20),  // padding
              4: FlexColumnWidth(1),  // takes up remaining space
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [TableRow(
              children: <Widget>[
                FutureBuilder(
                  future: World.world.profile.channelStatsFuture,
                  builder: (context, snapshot) => ChannelFilterMenu(
                    stats: snapshot.data,
                    initialChannelUrl: findPackages.selectedChannelUrl,
                    onSelectionChanged: (s) {
                      findPackages.updateChannelUrl(s);
                    },
                  ),
                ),
                const SizedBox(),
                FutureBuilder(
                  future: World.world.profile.channelStatsFuture,
                  builder: (context, snapshot) {
                    // if snapshot.hasError, this usually means /error/channels-not-available which can be ignored here
                    return CategoryMenu(
                      stats: switch (snapshot.data) {
                        null => null,  // data not yet available
                        final allStats => switch (allStats.channels.indexWhere((item) => item.url == findPackages.selectedChannelUrl)) {
                          -1 => allStats.combined,  // all channels selected
                          final i => allStats.channels[i].stats,
                        },
                      },
                      initialCategory: findPackages.selectedCategory,
                      menuHeight: max(300,
                        MediaQuery.of(context).size.height - _toolBarHeight
                        - MediaQuery.of(context).viewInsets.bottom,  // e.g. on-screen keyboard height
                      ),
                      onSelected: (s) {
                        findPackages.updateCategory(s);
                      },
                    );
                  },
                ),
                const SizedBox(),
                PackageSearchBar(
                  initialText: findPackages.searchTerm,
                  hintText: "search term or URL…",
                  onSubmitted: (String query) => findPackages.updateSearchTerm(query),
                  onCanceled: () => findPackages.updateSearchTerm(''),
                  resultsCount: findPackages.searchResult.then((data) => data.length),
                ),
              ],
            )],
          ),
        ),
        FutureBuilder<List<PackageSearchResultItem>>(
          future: findPackages.searchResult,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SliverToBoxAdapter(child: Center(child: ApiErrorWidget(ApiError.from(snapshot.error!))));
            } else if (!snapshot.hasData) {
              return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
            } else if (snapshot.data!.isEmpty) {
              return const SliverToBoxAdapter(child: ListTile(leading: Icon(Icons.search_off), title: Text("No search results.")));
            } else {
              // Next, create a SliverList
              return SliverList(
                // Use a delegate to build items as they're scrolled on screen.
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = snapshot.data![index];
                    final module = BareModule.parse(item.package);
                    return PackageTile(module, index,
                      summary: item.summary,
                      status: item.status,
                      debugChannelUrls: findPackages.customFilter?.debugChannelUrls,
                      refreshParent: findPackages.refreshSearchResult,
                      onToggled: (checked) => World.world.profile.dashboard.pendingUpdates.onToggledStarButton(module, checked, refreshParent: findPackages.refreshSearchResult),
                    );
                  },
                  childCount: snapshot.data!.length,
                ),
              );
            }
          },
        ),
      ]),
    );
  }
}

class ChannelFilterMenu extends StatefulWidget {
  final String? initialChannelUrl;
  final ChannelStatsAll? stats;
  final void Function(String?) onSelectionChanged;
  const ChannelFilterMenu({required this.stats, required this.initialChannelUrl, required this.onSelectionChanged, super.key});
  @override State<ChannelFilterMenu> createState() => _ChannelFilterMenuState();
}
class _ChannelFilterMenuState extends State<ChannelFilterMenu> {
  late String? _selectedChannelUrl = widget.initialChannelUrl;

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
          icon: _selectedChannelUrl == null ?
            const Icon(Symbols.stacks) :
            const RotatedBox(quarterTurns: 1, child: Icon(Symbols.hov)),
          tooltip: "Channels",
        );
      },
      menuChildren: List<MenuItemButton>.generate(
        switch (widget.stats) { null => 0, final stats => stats.channels.length + 1 },
        (int index) {
          final newUrl = index == 0 ? null : widget.stats?.channels[index-1].url;
          final color = _selectedChannelUrl == newUrl ? Theme.of(context).primaryColor : null;
          final style = DefaultTextStyle.of(context).style.copyWith(
            fontSize: Theme.of(context).textTheme.labelLarge?.fontSize,
            color: color,
          );
          return MenuItemButton(
            onPressed: () {
              if (_selectedChannelUrl != newUrl) {
                setState(() => _selectedChannelUrl = newUrl);
                widget.onSelectionChanged(newUrl);
              }
            },
            leadingIcon: index == 0 ? Icon(Symbols.stacks, color: color) : RotatedBox(quarterTurns: 1, child: Icon(Symbols.hov, color: color)),
            trailingIcon: switch (index == 0 ? widget.stats?.combined : widget.stats?.channels[index-1].stats) {
              null => null,
              final stats => Text(stats.totalPackageCount.toString(), style: style),
            },
            child: Text(index == 0 ? "All channels" : widget.stats?.channels[index-1].channelLabel ?? "Channel $index", style: style),
          );
        },
      ),
    );
  }
}
