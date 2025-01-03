import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'dart:math';
import '../data.dart';
import '../model.dart';
import '../viewmodel.dart';
import 'fragments.dart';

class FindPackagesScreen extends StatefulWidget {
  final FindPackages findPackages;
  const FindPackagesScreen(this.findPackages, {super.key});

  @override
  State<FindPackagesScreen> createState() => _FindPackagesScreenState();
}
class _FindPackagesScreenState extends State<FindPackagesScreen> {
  late Future<List<PackageSearchResultItem>> searchResultFuture;

  @override
  void initState() {
    super.initState();
    _search();
  }

  void _search() {
    final searchTerm = widget.findPackages.searchTerm;
    final category = widget.findPackages.selectedCategory;
    final channelUrl = widget.findPackages.selectedChannelUrl;
    if ((searchTerm?.isNotEmpty ?? false) || category != null) {
      searchResultFuture = World.world.client.search(searchTerm ?? '', category: category, channel: channelUrl, profileId: World.world.profile.id);
    } else {
      searchResultFuture = Future.value([]);
    }
  }

  void _refresh() {
    setState(() {
      _search();
    });
  }

  static const double _toolBarHeight = 100.0;

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
                    initialChannelUrl: widget.findPackages.selectedChannelUrl,
                    onSelectionChanged: (s) {
                      setState(() {
                        widget.findPackages.selectedChannelUrl = s;
                        _search();
                      });
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
                        final allStats => switch (allStats.channels.indexWhere((item) => item.url == widget.findPackages.selectedChannelUrl)) {
                          -1 => allStats.combined,  // all channels selected
                          final i => allStats.channels[i].stats,
                        },
                      },
                      initialCategory: widget.findPackages.selectedCategory,
                      menuHeight: max(300,
                        MediaQuery.of(context).size.height - _toolBarHeight
                        - MediaQuery.of(context).viewInsets.bottom,  // e.g. on-screen keyboard height
                      ),
                      onSelected: (s) {
                        setState(() {
                          widget.findPackages.selectedCategory = s;
                          _search();
                        });
                      },
                    );
                  },
                ),
                const SizedBox(),
                PackageSearchBar(
                  initialText: widget.findPackages.searchTerm,
                  hintText: "search term or URL…",
                  onSubmitted: (String query) => setState(() {
                    widget.findPackages.searchTerm = query;
                    _search();
                  }),
                  onCanceled: () => setState(() {
                    widget.findPackages.searchTerm = '';
                    _search();
                  }),
                  resultsCount: searchResultFuture.then((data) => data.length),
                ),
              ],
            )],
          ),
        ),
        FutureBuilder<List<PackageSearchResultItem>>(
          future: searchResultFuture,
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
                      refreshParent: _refresh,
                      onToggled: (checked) => World.world.profile.dashboard.pendingUpdates.onToggledStarButton(module, checked, refreshParent: _refresh),
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
