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
  late Future<List<PackageSearchResultItem>> futureJson;
  late final TextEditingController _searchBarController = TextEditingController(text: widget.findPackages.searchTerm);

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

  void _search() {
    final q = widget.findPackages.searchTerm;
    final c = widget.findPackages.selectedCategory;
    if ((q?.isNotEmpty ?? false) || c != null) {
      futureJson = Api.search(q ?? '', category: c, profileId: World.world.profile!.id);
    } else {
      futureJson = Future.value([]);
    }
  }

  static const double _toolBarHeight = 100.0;
  static const double _appBarHeight = _toolBarHeight;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          // Allows the user to reveal the app bar if they begin scrolling
          // back up the list of items.
          floating: true,
          // Display a placeholder widget to visualize the shrinking size.
          //flexibleSpace: Placeholder(),
          // Make the initial height of the SliverAppBar larger than normal.
          //expandedHeight: 200,
          toolbarHeight: _toolBarHeight,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              FutureBuilder(
                future: World.world.profile!.channelStatsFuture,
                builder: (context, snapshot) {
                  // if snapshot.hasError, this usually means /error/channels-not-available which can be ignored here
                  return CategoryMenu(
                    stats: snapshot.data,  // possibly null
                    initialCategory: widget.findPackages.selectedCategory,
                    menuHeight: max(300,
                      MediaQuery.of(context).size.height - _appBarHeight
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
                child: SearchBar(
                  controller: _searchBarController,
                  padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
                  leading: const Icon(Icons.search),
                  // or onChanged for immediate feedback?
                  onSubmitted: (String query) => setState(() {
                    widget.findPackages.searchTerm = query;
                    _search();
                  }),
                  trailing: [
                    FutureBuilder<List<PackageSearchResultItem>>(
                      future: futureJson,
                      builder: (context, snapshot) => Text((!snapshot.hasError && snapshot.hasData) ? '${snapshot.data!.length} packages' : ''),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
        FutureBuilder<List<PackageSearchResultItem>>(
          future: futureJson,
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
                    return PackageTile(module, index, subtitle: item.summary, status: item.status /*actionButton: AddPackageButton(module, false /*TODO*/)*/);
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
