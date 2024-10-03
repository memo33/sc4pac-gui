import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
import '../model.dart';
import '../viewmodel.dart';
import 'fragments.dart';
import 'packagepage.dart';

class FindPackagesScreen extends StatefulWidget {
  final FindPackages findPackages;
  const FindPackagesScreen(this.findPackages, {super.key});

  @override
  State<FindPackagesScreen> createState() => _FindPackagesScreenState();
}
class _FindPackagesScreenState extends State<FindPackagesScreen> {
  late Future<List<Map<String, dynamic>>> futureJson;
  late final TextEditingController _searchBarController = TextEditingController(text: widget.findPackages.searchTerm);

  @override
  void initState() {
    super.initState();
    futureJson = Api.search(_searchBarController.text);
  }

  @override
  void dispose() {
    _searchBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          // Provide a standard title.
          // title: Text('Title'),
          // Allows the user to reveal the app bar if they begin scrolling
          // back up the list of items.
          floating: true,
          // Display a placeholder widget to visualize the shrinking size.
          //flexibleSpace: Placeholder(),
          // Make the initial height of the SliverAppBar larger than normal.
          //expandedHeight: 200,
          bottom: PreferredSize(preferredSize: const Size.fromHeight(130.0), child: Column(  // TODO avoid setting explicit size
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 10),
              SearchBar(
                controller: _searchBarController,
                padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
                leading: const Icon(Icons.search),
                // or onChanged for immediate feedback?
                onSubmitted: (String query) => setState(() {
                  futureJson = Api.search(query);
                  widget.findPackages.searchTerm = query;
                }),  // TODO
                trailing: [
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: futureJson,
                    builder: (context, snapshot) => Text((!snapshot.hasError && snapshot.hasData) ? '${snapshot.data!.length} packages' : ''),
                  )
                ],
              ),
              const SizedBox(height: 20),
              const DropdownMenu<String>(
                width: 400,
                leadingIcon: Icon(Icons.category),
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
              // const SizedBox(height: 20),
              // const Text('Placeholder text'),
            ],
          )),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
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
                    if (snapshot.data![index] case {'package': String pkg, 'summary': String summary}) {
                      final module = BareModule.parse(pkg);
                      return PackageTile(module, index, subtitle: summary, /*actionButton: AddPackageButton(module, false /*TODO*/)*/);
                    }
                    return ApiErrorWidget(ApiError.unexpected('Malformed package data.', '${snapshot.data![index]}'));
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
