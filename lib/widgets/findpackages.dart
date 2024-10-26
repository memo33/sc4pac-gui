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
          // flexibleSpace: Placeholder(), // placeholder widget to visualize the shrinking size
          // expandedHeight: 200, // initial height of the SliverAppBar larger than normal
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
                    return PackageTile(module, index,
                      subtitle: item.summary,
                      status: item.status,
                      refreshParent: _refresh,
                      onToggled: (checked) {
                        final task = checked ?
                            Api.add(module, profileId: World.world.profile!.id) :
                            Api.remove(module, profileId: World.world.profile!.id);
                        task.then((_) => _refresh(), onError: ApiErrorWidget.dialog);
                      },
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
