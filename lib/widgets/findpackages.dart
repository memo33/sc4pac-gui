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
  @override State<FindPackagesScreen> createState() => _FindPackagesScreenState();
}
class _FindPackagesScreenState extends State<FindPackagesScreen> {

  static const double _toolBarHeight = 100.0;
  static const double _toolbarBottomHeight = 40.0;

  @override
  void initState() {
    super.initState();
    widget.findPackages.refreshSearchResult();  // important in case of Update or Add/Remove in other screens
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.findPackages,
      builder: (context, child) => CustomScrollView(slivers: [
        SliverAppBar(
          floating: true,
          // pinned: true,  // TODO consider pinning to avoid scroll physics auto-scrolling to top when touching app bar
          // flexibleSpace: Placeholder(), // placeholder widget to visualize the shrinking size
          // expandedHeight: 200, // initial height of the SliverAppBar larger than normal
          toolbarHeight: _toolBarHeight,
          title: widget.findPackages.customFilter != null
            ? CustomFilterBar(
                addedAll: widget.findPackages.addedAllInCustomFilter,
                enableReset: widget.findPackages.enableResetCustomFilter,
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
                  future: World.world.profile.channelStats.future,
                  builder: (context, snapshot) => ChannelFilterMenu(
                    stats: snapshot.data,
                    initialChannelUrl: widget.findPackages.selectedChannelUrl,
                    onSelectionChanged: (s) {
                      widget.findPackages.updateChannelUrl(s);
                    },
                  ),
                ),
                const SizedBox(),
                FutureBuilder(
                  future: World.world.profile.channelStats.future
                    .then((allStats) => widget.findPackages.searchResult.then((r) => (searchResult: r, allStats: allStats))),
                  builder: (context, snapshot) {
                    // if snapshot.hasError, this usually means /error/channels-not-available which can be ignored here
                    return CategoryMenu(
                      stats: switch (snapshot.data) {
                        null => null,  // data not yet available
                        final data =>
                          data.searchResult.stats ??
                            switch (data.allStats.channels.indexWhere((item) => item.url == widget.findPackages.selectedChannelUrl)) {
                              -1 => data.allStats.combined,  // all channels selected
                              final i => data.allStats.channels[i].stats,
                            },
                      },
                      initialCategory: widget.findPackages.selectedCategory,
                      menuHeight: max(300,
                        MediaQuery.of(context).size.height - _toolBarHeight
                        - MediaQuery.of(context).viewInsets.bottom,  // e.g. on-screen keyboard height
                      ),
                      onSelected: (s) {
                        widget.findPackages.updateCategory(s);
                      },
                    );
                  },
                ),
                const SizedBox(),
                PackageSearchBar(
                  initialText: widget.findPackages.searchTerm,
                  hintText: "search term or URL…",
                  onSubmitted: (String query) => widget.findPackages.updateSearchTerm(query),
                  onCanceled: () => widget.findPackages.updateSearchTerm(''),
                  resultsCount: widget.findPackages.searchResult.then((data) => data.packages.length),
                ),
              ],
            )],
          ),
          bottom: widget.findPackages.customFilter != null ? null : PreferredSize(
            preferredSize: const Size.fromHeight(_toolbarBottomHeight),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 5,
              children: <Widget>[
                Padding(padding: const EdgeInsets.only(bottom: 5), child: SegmentedButton<FindPkgToggleFilter>(
                  segments: [
                    const ButtonSegment(
                      value: FindPkgToggleFilter.includeInstalled,
                      label: Text("Installed"),
                      tooltip: "Deselect to hide packages already installed",
                    ),
                    ButtonSegment(
                      value: FindPkgToggleFilter.includeResources,
                      label: const Text("Props/textures/resources"),
                      enabled: widget.findPackages.includeResourcesFilterEnabled(),
                      tooltip: widget.findPackages.includeResourcesFilterEnabled()
                        ? "Deselect to hide such dependency packages from the results"
                        : "Disabled while a Category is selected",
                    ),
                  ],
                  showSelectedIcon: true,
                  multiSelectionEnabled: true,
                  emptySelectionAllowed: true,
                  selected: widget.findPackages.selectedToggleFilters,
                  onSelectionChanged: widget.findPackages.updateToggleFilters,
                )),
              ],
            ),
          ),
        ),
        FutureBuilder<PackageSearchResult>(
          future: widget.findPackages.searchResult,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SliverToBoxAdapter(child: Center(child: ApiErrorWidget(ApiError.from(snapshot.error!))));
            } else if (!snapshot.hasData) {
              return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
            } else if (snapshot.data!.packages.isEmpty) {
              final noResultsText =
                widget.findPackages.searchWithAnyFilterActive() ? "No search results. Check the filtering options." :
                widget.findPackages.noCategoryOrSearchActive() ? "No search results. Select a Category or use the Search." :
                "No search results.";
              final theme = Theme.of(context);
              final hintStyle = theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor);
              final channelStats = World.world.profile.channelStats;
              return SliverFillRemaining(
                hasScrollBody: false,
                child: ListenableBuilder(
                  listenable: channelStats,
                  builder: (context, child) => Column(
                    children: channelStats.error != null
                      ? [ApiErrorWidget(ApiError.from(channelStats.error!, title: "Failed to load channel contents. Check your internet connection."))]
                      : channelStats.data == null
                      ? [
                        const ListTile(leading: Icon(Symbols.hourglass), title: Text("Loading channel contents…")),
                        if (channelStats.timedout == true)
                          const ListTile(title: Text("This is taking longer than expected. Check your internet connection.")),
                      ]
                      : [
                        ListTile(leading: const Icon(Icons.search_off), title: Text(noResultsText)),
                        const Spacer(),
                        ListTile(
                          leading: const Icon(Symbols.lightbulb),
                          iconColor: theme.hintColor,
                          titleTextStyle: hintStyle,
                          title: const Text.rich(TextSpan(
                            children: <InlineSpan>[
                              TextSpan(text: "Couldn't find what you're looking for? Try the "),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Hyperlink(text: "interactive YAML editor", url: "https://yamleditorforsc4pac.net/"),
                              ),
                              TextSpan(text: " to add new "),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Hyperlink(text: "metadata", url: "https://memo33.github.io/sc4pac/#/metadata?id=testing-your-changes"),
                              ),
                              TextSpan(text: " for plugins that are not available with sc4pac yet."),
                            ],
                          )),
                        ),
                        const SizedBox(height: 20),
                      ],
                  ),
                ),
              );
            } else {
              final searchResult = snapshot.data!;
              return SliverList(
                // Use a delegate to build items as they're scrolled on screen.
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = searchResult.packages[index];
                    return PackageTile(item.module, index,
                      summary: item.summary,
                      status: item.status,
                      debugChannelUrls: widget.findPackages.customFilter?.debugChannelUrls,
                      refreshParent: widget.findPackages.refreshSearchResult,
                      onToggled: (checked) =>
                        World.world.profile.dashboard.pendingUpdates.onToggledStarButton(item.module, checked)
                          .then((_) => widget.findPackages.refreshSearchResult()),
                    );
                  },
                  childCount: searchResult.packages.length,
                ),
              );
            }
          },
        ),
      ]),
    );
  }
}

class CustomFilterBar extends StatelessWidget {
  final bool addedAll;
  final bool enableReset;
  const CustomFilterBar({required this.addedAll, required this.enableReset, super.key});

  @override Widget build(BuildContext context) {
    return Wrap(
      direction: Axis.horizontal,
      spacing: 15,
      children: [
        InputChip(
          label: const Text("Custom package filter"),
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
          onDeleted: () {
            World.world.profile.findPackages.updateCustomFilter(null);
          },
        ),
        OutlinedButton.icon(
          icon: Icon(Symbols.hotel_class, fill: addedAll ? 1 : 0),
          label: const Text("Add all"),
          onPressed: () => World.world.profile.findPackages.onCustomFilterAddAllButton(),
        ),
        switch (OutlinedButton.icon(
          icon: InstalledStatusIconExplicit(  // TODO try using Icon.blendMode with Flutter 3.27+ for correct background coloring on hover
            badgeScale: 1.1,
            fill: 0,
            child: Transform.rotate(angle: -2.3, child: const Icon(Symbols.replay)),
          ),
          label: const Text("Reset"),
          onPressed: enableReset ? () => World.world.profile.findPackages.onCustomFilterResetButton() : null,
        )) {
          final button => enableReset ? Tooltip(message: "Restore previous state", child: button) : button
        },
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
