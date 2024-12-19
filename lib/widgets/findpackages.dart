import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
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
    final q = widget.findPackages.searchTerm;
    final c = widget.findPackages.selectedCategory;
    if ((q?.isNotEmpty ?? false) || c != null) {
      searchResultFuture = World.world.client.search(q ?? '', category: c, profileId: World.world.profile.id);
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
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              FutureBuilder(
                future: World.world.profile.channelStatsFuture,
                builder: (context, snapshot) {
                  // if snapshot.hasError, this usually means /error/channels-not-available which can be ignored here
                  return CategoryMenu(
                    stats: snapshot.data,  // possibly null
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
              const SizedBox(width: 20),
              Expanded(
                child: PackageSearchBar(
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
              ),
            ],
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
