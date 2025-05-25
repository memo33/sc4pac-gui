// The classes in this file model the app state, i.e. state that is kept while the app is running.
// The view usually builds its widgets from this state.
//
// This is in contrast to ephemeral state (short-lived state implemented by StatefulWidget subclasses)
// and persistent state (long-lived state that outlives the running app and is stored on disk using the sc4pac API).
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:app_links/app_links.dart';
import 'dart:io';
import 'protocol_handler_none.dart'  // web
  if (dart.library.io) 'protocol_handler.dart'  // desktop
  as protocol_handler;
import 'model.dart';
import 'data.dart';
import 'widgets/dashboard.dart';
import 'widgets/fragments.dart';
import 'widgets/packagepage.dart';
import 'main.dart' show CommandlineArgs, NavigationService;

enum InitPhase { connecting, loadingProfiles, initializingProfile, initialized }

class World extends ChangeNotifier {
  final CommandlineArgs args;
  final PackageInfo appInfo;
  final appLinks = AppLinks();
  bool appLinksInitialized = false;
  InitPhase initPhase = InitPhase.connecting;
  late String authority;
  Sc4pacServer? server;
  late Future<Map<String, dynamic>> initialServerStatus;
  String? serverVersion;
  String? serverStatusOs;
  late Sc4pacClient client;
  late Future<Profiles> profilesFuture;
  Profiles? profiles;
  bool createNewProfile = false;
  bool profileInitialized = false;
  late Profile profile;
  late Future<({bool initialized, Map<String, dynamic> data})> readProfileFuture;
  SettingsData? settings;
  int navRailIndex = 0;
  // themeMode
  // other gui settings

  void updateConnection(String authority, {required bool notify}) {
    initPhase = InitPhase.connecting;
    this.authority = authority;
    initialServerStatus = (server?.ready ?? Future.value(true)).then((isReady) =>
      isReady ? Sc4pacClient.serverStatus(authority)
        : Future.error(server?.launchError ?? ApiError.unexpected("Failed to launch local sc4pac server (unknown reason).", Sc4pacServer.unknownLaunchErrorDetail))
      );
    initialServerStatus.then(
      (serverStatus) {  // connection succeeded, so proceed to next phase
        if (serverStatus case {'sc4pacVersion': String version}) {
          serverVersion = version;
        }
        if (serverStatus case {'osVersion': String osVersion}) {
          serverStatusOs = osVersion;
        }
        client = Sc4pacClient(
          authority,
          onConnectionLost: () => updateConnection(authority, notify: true),
          openPackages: openPackages,
        );
        _switchToLoadingProfiles();
      },
      onError: (_) {},  // connection failed, so stay in InitPhase.connecting
    );
    if (notify) {
      notifyListeners();
    }
  }

  void reloadProfiles({required bool createNewProfile}) {
    this.createNewProfile = createNewProfile;
    _switchToLoadingProfiles();
  }

  void updateProfilesFast() {
    profilesFuture = client.profiles()
      ..then((profiles) => this.profiles = profiles);
  }

  void _switchToLoadingProfiles() {
    initPhase = InitPhase.loadingProfiles;
    profilesFuture =
      client.getSettings()
      .then(updateSettings)
      .then((_) => client.profiles())
      ..then((profiles) => this.profiles = profiles);
    notifyListeners();
  }

  void updateProfile(({String id, String name}) p) {
    createNewProfile = false;
    profile = Profile(p.id, p.name);
    profileInitialized = true;
    _switchToInitialzingProfile();
  }

  void _switchToInitialzingProfile() {
    initPhase = InitPhase.initializingProfile;
    readProfileFuture = client.profileRead(profileId: profile.id);
    notifyListeners();
  }

  void updatePaths(({String plugins, String cache}) paths) {
    profile.paths = paths;
    _switchToInitialized();
  }

  void _switchToInitialized() async {
    if (!kIsWeb && !appLinksInitialized) {
      appLinks.stringLinkStream.listen((String arg) {
        // if sc4pac-gui is invoked when application is already running, this might be the second argument, which must be ignored
        if (arg.startsWith(CommandlineArgs.sc4pacProtocol)) {
          final u = Uri.tryParse(arg);
          if (u != null) {
            _handleSc4pacUrl(u);
          }
        }
      });
      appLinksInitialized = true;
      if (args.registerProtocol) {
        await protocol_handler.registerProtocolScheme(CommandlineArgs.sc4pacProtocolScheme, args.profilesDir)
          .catchError((e) => ApiErrorWidget.dialog(ApiError.unexpected(
            """Failed to register "${CommandlineArgs.sc4pacProtocol}" URL scheme in Windows registry.""",
            e.toString(),
          )));
      }
    }

    initPhase = InitPhase.initialized;
    notifyListeners();
  }

  void updateSettings(SettingsData settings) {
    this.settings = settings;
    notifyListeners();
  }

  static late World world;

  World({required this.args, required this.appInfo}) {
    World.world = this;  // TODO for simplicity of access, we store a static reference to the one world

    const envPort = bool.hasEnvironment("port") ? int.fromEnvironment("port") : null;
    const envHost = bool.hasEnvironment("host") ? String.fromEnvironment("host") : null;
    final int port = args.port ?? envPort ?? Sc4pacClient.defaultPort;
    if (args.host != null || args.port != null || envHost != null || envPort != null) {
      final h = args.host ?? envHost ?? "localhost";
      authority = "$h:$port";
    } else {
      // for web, api server and webapp server are identical by default
      authority = kIsWeb ? Uri.base.authority : "localhost:$port";
    }

    if (!kIsWeb && args.launchServer) {
      final String bundleRoot = FileSystemEntity.parentOf(Platform.resolvedExecutable);
      server = Sc4pacServer(
        cliDir: args.cliDir ?? "$bundleRoot/cli",
        profilesDir: args.profilesDir,
        port: port,
      );
    } else {
      server = null;
    }

    updateConnection(authority, notify: false);
  }

  static const _supportedSc4pacUrlParameters = {'pkg', 'channel', 'externalIdProvider', 'externalId'};

  // routing
  void _handleSc4pacUrl(Uri url) async {
    if (url.path == "/package") {
      List<BareModule> packages = url.queryParametersAll['pkg']?.map(BareModule.parse).toList() ?? [];
      Set<String> channelUrls = url.queryParametersAll['channel']?.toSet() ?? {};
      String? externalIdProvider = url.queryParameters['externalIdProvider'];
      Map<String, List<String>> externalIds =
        externalIdProvider == null
        ? {}
        : switch (url.queryParametersAll['externalId'] ?? []) {
          final ids => ids.isEmpty ? {} : {externalIdProvider: ids}
        };
      final unsupportedParameters = url.queryParametersAll.keys.where((key) => !_supportedSc4pacUrlParameters.contains(key));
      if (unsupportedParameters.isNotEmpty) {
        final detail = "Unsupported query parameters: ${unsupportedParameters.map((key) => '"$key"').join(", ")}";
        debugPrint(detail);
        await ApiErrorWidget.dialog(ApiError.unexpected(
          "Unsupported URL query parameters. Make sure you have the latest version of sc4pac and that the URL is correct.",
          detail,
        ));
      }
      openPackages(packages, externalIds: externalIds, channelUrls: channelUrls);
    } else {
      final detail = 'Unsupported URL path: "${url.path}"';
      debugPrint(detail);
      ApiErrorWidget.dialog(ApiError.unexpected(
        "Unsupported URL path. Make sure you have the latest version of sc4pac and that the URL is correct.",
        detail,
      ));
    }
  }

  void openPackages(List<BareModule> packages, {Map<String, List<String>> externalIds = const {}, required Set<String> channelUrls}) async {
    if (packages.isNotEmpty || externalIds.isNotEmpty) {
      if (packages.length == 1 && externalIds.isEmpty) {  // single package is opened directly
        final module = packages.first;
        final context = NavigationService.navigatorKey.currentContext;
        if (context != null && context.mounted) {
          PackagePage.pushPkg(context, module, debugChannelUrls: channelUrls, refreshPreviousPage: () {});  // refresh not possible since current page can be anything
        }
      } else {  // multiple packages are opened in FindPackages screen
        // TODO ensure channel is known before searching for externalIds
        profile.findPackages.updateCustomFilter((packages: packages, externalIds: externalIds, debugChannelUrls: channelUrls));
        navRailIndex = 1;  // switch to FindPackages
        final context = NavigationService.navigatorKey.currentContext;
        if (context != null && context.mounted) {
          Navigator.popUntil(context, ModalRoute.withName('/'));  // close potential package pages
        }
        notifyListeners();
      }
    }
  }
}

class Profile {
  final String id;
  final String name;
  ({String plugins, String cache})? paths;
  late Dashboard dashboard = Dashboard(this);
  late FindPackages findPackages = FindPackages();
  late MyPlugins myPlugins = MyPlugins();
  late Future<ChannelStatsAll> channelStatsFuture = World.world.client.channelsStats(profileId: id)
      ..then<void>((_) {}, onError: ApiErrorWidget.dialog);
  Profile(this.id, this.name);
}

enum FindPkgToggleFilter { includeInstalled, includeResources }

typedef CustomFilter = ({List<BareModule> packages, Map<String, List<String>> externalIds, Set<String> debugChannelUrls});

class FindPackages extends ChangeNotifier {
  String? _searchTerm;
  String? get searchTerm => _searchTerm;
  String? _selectedCategory;
  String? get selectedCategory => _selectedCategory;
  String? _selectedChannelUrl;
  String? get selectedChannelUrl => _selectedChannelUrl;
  final Set<FindPkgToggleFilter> _selectedToggleFilters = {FindPkgToggleFilter.includeInstalled, FindPkgToggleFilter.includeResources};
  Set<FindPkgToggleFilter> get selectedToggleFilters => _selectedToggleFilters;
  CustomFilter? _customFilter;
  CustomFilter? get customFilter => _customFilter;
  bool _alreadyAskedAddingChannelsFromFilter = false;
  late Future<PackageSearchResult> _customFilterOrigState = Future.value(PackageSearchResult.empty);
  bool _enableResetCustomFilter = false;
  bool get enableResetCustomFilter => _enableResetCustomFilter;
  set enableResetCustomFilter(bool enable) {
    if (enable != _enableResetCustomFilter) {
      _enableResetCustomFilter = enable;
      notifyListeners();
    }
  }
  bool _addedAllInCustomFilter = false;
  bool get addedAllInCustomFilter => _addedAllInCustomFilter;
  set addedAllInCustomFilter(bool addedAll) {
    if (addedAll != _addedAllInCustomFilter) {
      _addedAllInCustomFilter = addedAll;
      notifyListeners();
    }
  }
  Future<PackageSearchResult> searchResult = Future.value(PackageSearchResult.empty);

  void _search() {
    if (customFilter != null) {
      searchResult = World.world.client.searchById(
        customFilter?.packages ?? [],
        externalIds: customFilter?.externalIds,
        profileId: World.world.profile.id,
      ).then((PackageSearchResult data) {
        final debugChannelUrls = customFilter?.debugChannelUrls;
        if ((data.notFoundExternalIdCount > 0 || data.notFoundPackageCount > 0)
          && !_alreadyAskedAddingChannelsFromFilter
          && debugChannelUrls != null && debugChannelUrls.isNotEmpty
        ) {
          _alreadyAskedAddingChannelsFromFilter = true;
          World.world.profile.dashboard.addUnknownChannelUrls(debugChannelUrls)  // async
            .then((channelsAdded) {
              if (channelsAdded) {
                refreshSearchResult();
              }
            });
        }
        return data;
      });
    } else if (searchTerm?.isNotEmpty == true || selectedCategory != null) {
      final Future<List<String>> notCategoriesFuture =
        !includeResourcesFilterEnabled() || selectedToggleFilters.contains(FindPkgToggleFilter.includeResources)
          ? Future.value(const [])
          : World.world.profile.channelStatsFuture.then((stats) =>
              stats.combined.categories
                .map((c) => c.category)
                .where((c) => c.startsWith("10") || c.startsWith("11")).toList()  // 100-props-textures, 110-resources
            );
      searchResult = notCategoriesFuture.then((notCategories) => World.world.client.search(
        searchTerm ?? '',
        category: selectedCategory,
        notCategories: notCategories,
        channel: selectedChannelUrl,
        ignoreInstalled: !selectedToggleFilters.contains(FindPkgToggleFilter.includeInstalled),
        profileId: World.world.profile.id,
      ));
    } else {
      searchResult = Future.value(PackageSearchResult.empty);
    }
    notifyListeners();
  }

  void refreshSearchResult() => _search();

  void updateSearchTerm(String searchTerm) {
    if (searchTerm != _searchTerm) {
      _searchTerm = searchTerm;
      _search();
    }
  }

  void updateCategory(String? selectedCategory) {
    if (selectedCategory != _selectedCategory) {
      _selectedCategory = selectedCategory;
      _search();
    }
  }

  void updateChannelUrl(String? selectedChannelUrl) {
    if (selectedChannelUrl != _selectedChannelUrl) {
      _selectedChannelUrl = selectedChannelUrl;
      _search();
    }
  }

  void updateToggleFilters(Set<FindPkgToggleFilter> newSelection) {
    if (newSelection != _selectedToggleFilters) {
      _selectedToggleFilters.clear();
      _selectedToggleFilters.addAll(newSelection);
      _search();
    }
  }

  bool includeResourcesFilterEnabled() => selectedCategory == null;

  bool searchWithAnyFilterActive() =>
      _searchTerm?.isNotEmpty == true &&
      (_selectedChannelUrl != null || _selectedCategory != null || _selectedToggleFilters.length < FindPkgToggleFilter.values.length);

  bool noCategoryOrSearchActive() => _selectedCategory == null && _searchTerm?.isNotEmpty != true;

  void updateCustomFilter(CustomFilter? customFilter) {
    if (customFilter != _customFilter) {
      _customFilter = customFilter;
      _alreadyAskedAddingChannelsFromFilter = false;
      _enableResetCustomFilter = false;
      _addedAllInCustomFilter = false;
      _search();
      _customFilterOrigState = searchResult;
    }
  }

  void onCustomFilterResetButton() {
    enableResetCustomFilter = false;
    addedAllInCustomFilter = false;
    searchResult.then<void>((result) async {
      final origResult = await _customFilterOrigState;
      final Map<String, InstalledStatus?> currentStates = {for (final item in result.packages) item.package: item.status};
      await World.world.profile.dashboard.pendingUpdates.toggleMany(
        toAdd:    origResult.packages.where((item) => item.status?.explicit == true && currentStates[item.package]?.explicit != true).toList(),
        toRemove: origResult.packages.where((item) => item.status?.explicit != true && currentStates[item.package]?.explicit == true).toList(),
        reset: true,
      );
      refreshSearchResult();
    })
    .catchError(ApiErrorWidget.dialog);
    // async, but we do not need to await result
  }

  // removes all on second click
  void onCustomFilterAddAllButton() {
    final bool addAll = !addedAllInCustomFilter;
    addedAllInCustomFilter = addAll;
    searchResult.then<void>((result) async {
      final modulesToToggle =
        result.packages.where((item) => item.status?.explicit != addAll).toList();
      if (modulesToToggle.isNotEmpty) {
        enableResetCustomFilter = true;
        if (addAll) {
          await World.world.profile.dashboard.pendingUpdates.toggleMany(toAdd: modulesToToggle, reset: false);
        } else {
          await World.world.profile.dashboard.pendingUpdates.toggleMany(toRemove: modulesToToggle, reset: false);
        }
        refreshSearchResult();
      }
    })
    .catchError(ApiErrorWidget.dialog);
    // async, but we do not need to await result
  }
}

enum InstallStateType { markedForInstall, explicitlyInstalled, installedAsDependency }
enum SortOrder { relevance, updated, installed }

class MyPlugins {
  String? searchTerm;
  String? selectedCategory;
  Set<InstallStateType> installStateSelection =
    {/*InstallStateType.markedForInstall,*/ InstallStateType.explicitlyInstalled, InstallStateType.installedAsDependency};
  SortOrder sortOrder = SortOrder.relevance;  // default order as returned by Api

  void import(ExportData data) {
    final variants = data.variants ?? data.config?.variant;
    if (variants?.isNotEmpty == true) {
      World.world.profile.dashboard.importedVariantSelections.add(variants!);
    }
    World.world.openPackages(
      data.explicit?.map(BareModule.parse).toList() ?? [],
      channelUrls: (data.channels ?? data.config?.channels)?.toSet() ?? {},
    );
  }
}

enum PendingUpdateStatus { add, remove, reinstall }

class Dashboard extends ChangeNotifier {
  UpdateProcess? _updateProcess;
  UpdateProcess? get updateProcess => _updateProcess;
  set updateProcess(UpdateProcess? updateProcess) {
    _updateProcess = updateProcess;
    notifyListeners();
  }
  final Profile profile;
  final pendingUpdates = PendingUpdates();
  final List<Map<String, String>> importedVariantSelections = [];  // FIFO, newest at the back
  late Future<VariantsList> variantsFuture;
  late Future<List<String>> channelUrls = World.world.client.channelsList(profileId: profile.id);
  Dashboard(this.profile) {
    fetchVariants();
  }

  void fetchVariants() {
    variantsFuture = World.world.client.variantsList(profileId: profile.id);
    notifyListeners();
  }

  void onUpdateFinished(UpdateStatus status) {
    if (status == UpdateStatus.finished) {  // no error/no canceled
      pendingUpdates.clear();
      importedVariantSelections.clear();
    }
    fetchVariants();
    profile.channelStatsFuture = World.world.client.channelsStats(profileId: profile.id)
        // we ignore errors here (e.g. channel server down) as they will be displayed in the Update process log
        ..then<void>((_) {}, onError: (_) {});
    notifyListeners();
  }

  Future<void> updateChannelUrls(List<String> urls) {
    return World.world.client.channelsSet(urls, profileId: World.world.profile.id).then(
      (_) {
        channelUrls = World.world.client.channelsList(profileId: profile.id);
        profile.channelStatsFuture = World.world.client.channelsStats(profileId: World.world.profile.id)
            ..then<void>((_) {}, onError: ApiErrorWidget.dialog);
      },
      onError: (e) => throw ApiError.unexpected("Malformed channel URLs", "Something does not look like a proper URL."),
    );
  }

  Future<bool> addUnknownChannelUrls(Set<String> debugChannelUrls) async {
    final myChannelUrls = await World.world.client.channelsList(profileId: World.world.profile.id);
    final unknownChannelUrls = debugChannelUrls.difference(myChannelUrls.toSet()).toList();
    if (unknownChannelUrls.isNotEmpty) {
      bool? confirmed = await PackagePage.showUnknownChannelsDialog(unknownChannelUrls);
      if (confirmed == true) {
        await updateChannelUrls(myChannelUrls + unknownChannelUrls);
        return true;
      }
    }
    return false;
  }

  Future<void> selectVariant(BareModule module, {required String variantId, required String? installedValue}) {
    return World.world.client.variantsChoices(module, variantId: variantId, profileId: World.world.profile.id)
      .then<void>((msg) async {
        final choice = await DashboardScreen.showVariantDialog(msg, installedValue: installedValue, hidePreviousChoice: true);
        if (choice != null) {
          await World.world.client.variantsSet({variantId: choice}, profileId: World.world.profile.id);
          if (installedValue != null) {
            pendingUpdates.onSwitchedVariant(module);
          }
          fetchVariants();
        }
      })
      .catchError(ApiErrorWidget.dialog);
  }

  static void sortVariants<A>(List<A> entries, {required List<String> Function(A) keyParts}) {
    entries.sort((a, b) {  // first global, then local variants (first leafs, then nodes -> recursively)
      final aKeyParts = keyParts(a);
      final bKeyParts = keyParts(b);
      int i = 0;
      for (; i < aKeyParts.length - 1 && i < bKeyParts.length - 1; i++) {
        final c = aKeyParts[i].toLowerCase().compareTo(bKeyParts[i].toLowerCase());
        if (c != 0) return c;  // different parent nodes
      }
      // same parent nodes at level i-1
      final c = aKeyParts.length.compareTo(bKeyParts.length);
      if (c != 0) return c;  // mixed leafs/nodes at level i
      return aKeyParts[i].toLowerCase().compareTo(bKeyParts[i].toLowerCase());  // leafs at level i
    });
  }

}

class PendingUpdates extends ChangeNotifier {

  final Map<BareModule, PendingUpdateStatus> _overwrites = {};  // these are used as overrides of package installation states in the UI
  // Mark the explicit-install state for a package. If the star button is toggled twice, this removes the package from `pendingUpdates` again.
  void setPendingUpdate(BareModule pkg, PendingUpdateStatus status) {
    final previous = _overwrites[pkg];
    if (previous == null) {
      _overwrites[pkg] = status;
      notifyListeners();
    } else if (previous == status) {
      // nothing to do
    } else if (previous == PendingUpdateStatus.reinstall || status == PendingUpdateStatus.reinstall) {
      _overwrites[pkg] = status;
      notifyListeners();
    } else if (previous != status) {  // add/remove only
      _overwrites.remove(pkg);
      notifyListeners();
    } else {
      // should never happen
    }
  }
  void clear() {
    _overwrites.clear();
    notifyListeners();
  }

  void onSwitchedVariant(BareModule module) {
    setPendingUpdate(module, PendingUpdateStatus.reinstall);
  }

  Future<void> onToggledStarButton(BareModule module, bool checked) {
    final task = checked ?
        World.world.client.add([module], profileId: World.world.profile.id) :
        World.world.client.remove([module], profileId: World.world.profile.id);
    return task.then((_) {
      World.world.profile.findPackages.enableResetCustomFilter = true;
      World.world.profile.findPackages.addedAllInCustomFilter = false;
      setPendingUpdate(module, checked ? PendingUpdateStatus.add : PendingUpdateStatus.remove);
    }, onError: ApiErrorWidget.dialog);  // async, but we do not need to await result
  }

  // on toggling multiple star buttons simultaneously (e.g. Add All or Reset)
  Future<void> toggleMany({List<PackageSearchResultItem> toAdd = const [], List<PackageSearchResultItem> toRemove = const [], required bool reset}) async {
    await World.world.client.remove(toRemove.map((item) => item.module).toList(), profileId: World.world.profile.id);
    await World.world.client.add(toAdd.map((item) => item.module).toList(), profileId: World.world.profile.id);
    for (final item in toRemove) {
      if (_shouldSetPendingUpdate(item, removed: reset ? true : false)) {
        World.world.profile.dashboard.pendingUpdates.setPendingUpdate(item.module, PendingUpdateStatus.remove);
      }
    }
    for (final item in toAdd) {
      if (_shouldSetPendingUpdate(item, removed: reset ? false : true)) {
        World.world.profile.dashboard.pendingUpdates.setPendingUpdate(item.module, PendingUpdateStatus.add);
      }
    }
  }

  bool _shouldSetPendingUpdate(PackageSearchResultItem item, {required bool removed}) {
    if (removed) {
      return item.status?.installed != null && item.status?.explicit != true || item.status == null;
    } else {
      return !(item.status?.installed != null && item.status?.explicit != true);
    }
  }

  int getCount() {
    return _overwrites.length;
  }

  List<MapEntry<BareModule, PendingUpdateStatus>> sortedEntries() {
    final elems = _overwrites.entries.toList();
    elems.sort((a, b) => BareModule.compareAlphabetically(a.key, b.key));
    return elems;
  }
}

enum UpdateStatus { running, finished, finishedWithError, canceled }

class UpdateProcess extends ChangeNotifier {
  late final WebSocketChannel _ws;
  late final Stream<Map<String, dynamic>> _stream;

  UpdatePlan? plan;
  final downloads = <String>[];
  final Map<String, int> downloadLength = {};
  final Map<String, int> downloadDownloaded = {};
  final Map<String, bool> downloadSuccess = {};
  bool downloadsFailed = false;
  bool downloadsCompleted = false;
  bool _downloadsCompletedOnNextNonProgressDownloadMsg = false;
  ProgressUpdateExtraction? extractionProgress;
  bool _extractionFinishedOnNextMsg = false;
  bool extractionFinished = false;
  ApiError? err;

  UpdateStatus _status = UpdateStatus.running;
  UpdateStatus get status => _status;
  set status(UpdateStatus status) {
    _status = status;
    if (_status != UpdateStatus.running) {
      onFinished(_status);
    }
  }

  final PendingUpdates pendingUpdates;
  final void Function(UpdateStatus) onFinished;
  final bool isBackground;
  final List<Map<String, String>> importedVariantSelections;

  UpdateProcess({required this.pendingUpdates, required this.onFinished, required this.isBackground, required this.importedVariantSelections}) {
    final stAuth = World.world.settings?.stAuth;
    {
      _ws = World.world.client.update(
        profileId: World.world.profile.id,
        simtropolisToken: stAuth?.token,
        refreshChannels: World.world.settings?.refreshChannels ?? false,
      );
      _stream = _ws.ready
        .then((_) => true, onError: (e) {
          err = ApiError.unexpected('Failed to open websocket. Make sure the local sc4pac server is running.', e.toString());
          status = UpdateStatus.finishedWithError;
          return false;
        })
        .asStream()
        .asyncExpand((isReady) => !isReady
          ? const Stream<Map<String, dynamic>>.empty()
          : _ws.stream.map((data) {
            return jsonDecode(data as String) as Map<String, dynamic>;  // TODO jsonDecode could be run on a background thread
          })
        );
      _ws.sink.done.then((_) {
        if (status == UpdateStatus.running) {
          status = UpdateStatus.finishedWithError;
          // this can happen if sc4pac process crashes, so no final message is sent through the websocket before closing
          err ??= ApiError.unexpected(
            "Websocket closed unexpectedly. This seems to be a bug in sc4pac itself. Please report it.",
            World.world.server?.stderrBuffer.join("\n") ?? "",
          );
        }
      });
      _stream.listen(handleMessage);
    }
  }

  void cancel() {
    _ws.sink.close();
    status = UpdateStatus.canceled;
  }

  static final messageHandlers =
    Map.unmodifiable(<String, void Function(UpdateProcess self, Map<String, dynamic> data)>{
      '/prompt/json/update/initial-arguments': (self, data) {
        final msg = UpdateInitialArguments.fromJson(data);
        self._ws.sink.add(jsonEncode({
          '\$type': '/prompt/response',
          'token': msg.token,
          'body': {
            'importedSelections': self.importedVariantSelections.reversed.toList(),  // switching to LIFO
          },
        }));
      },
      '/prompt/confirmation/update/plan': (self, data) {
        final plan = UpdatePlan.fromJson(data);
        self.plan = plan;
        for (final entry in plan.changes.entries) {
          final change = entry.value;
          self.pendingUpdates.setPendingUpdate(BareModule.parse(entry.key),
            change.versionTo == null ? PendingUpdateStatus.remove :
            change.versionFrom == null ? PendingUpdateStatus.add :
            PendingUpdateStatus.reinstall,
          );
        }
        if (self.isBackground) {
          self.cancel();  // for background process we are done, as we do not want to install anything
        } else if (plan.nothingToDo){
          self._ws.sink.add(jsonEncode(plan.responses['Yes']));  // everything up-to-date
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DashboardScreen.showUpdatePlan(plan)
              .then((choice) => self._ws.sink.add(jsonEncode(plan.responses[choice])));
          });
        }
      },
      '/prompt/confirmation/update/warnings': (self, data) {  // not relevant for isBackground, as these warnings are triggered during installation
        final msg = ConfirmationUpdateWarnings.fromJson(data);
        if (msg.warnings.isEmpty) {
          self._ws.sink.add(jsonEncode(msg.responses['Yes']));  // no warnings
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DashboardScreen.showWarningsDialog(msg)
              .then((choice) => self._ws.sink.add(jsonEncode(msg.responses[choice])));
          });
        }
      },
      '/prompt/choice/update/variant': (self, data) {
        final msg = ChoiceUpdateVariant.fromJson(data);
        if (self.isBackground) {
          // we cannot make this selection without user interaction
          self.pendingUpdates.setPendingUpdate(BareModule.parse(msg.package), PendingUpdateStatus.reinstall);
          self.cancel();
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DashboardScreen.showVariantDialog(msg).then((choice) {
              if (choice == null) {
                self.cancel();
              } else {
                self._ws.sink.add(jsonEncode(msg.responses[choice]));
              }
            });
          });
        }
      },
      '/prompt/confirmation/update/remove-unresolvable-packages': (self, data) {
        final msg = ConfirmationRemoveUnresolvablePackages.fromJson(data);
        if (self.isBackground) {
          self.cancel();  // we cannot make this selection without user interaction
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DashboardScreen.showRemoveUnresolvablePkgsDialog(msg).then((choice) {
              if (choice == null) {
                self.cancel();
              } else {
                self._ws.sink.add(jsonEncode(msg.responses[choice]));
              }
            });
          });
        }
      },
      '/prompt/choice/update/remove-conflicting-packages': (self, data) {
        final msg = ChoiceRemoveConflictingPackages.fromJson(data);
        if (self.isBackground) {
          self.cancel();  // we cannot make this selection without user interaction
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DashboardScreen.showRemoveConflictingPkgsDialog(msg).then((choice) {
              if (choice == null) {
                self.cancel();
              } else {
                self._ws.sink.add(jsonEncode(msg.responses[choice]));
              }
            });
          });
        }
      },
      '/prompt/json/update/download-failed-select-mirror': (self, data) {
        final msg = DownloadFailedSelectMirror.fromJson(data);
        if (self.isBackground) {
          self.cancel();  // we cannot make this selection without user interaction
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DashboardScreen.showSelectMirrorDialog(msg).then((respData) {
              if (respData == null) {
                self.cancel();
              } else {
                self._ws.sink.add(jsonEncode({
                  '\$type': '/prompt/response',
                  'token': msg.token,
                  'body': {'retry': respData.retry, 'localMirror': respData.localMirror},
                }));
              }
            });
          });
        }
      },
      '/prompt/confirmation/update/installing-dlls': (self, data) {
        final msg = ConfirmationInstallingDlls.fromJson(data);
        if (self.isBackground) {
          self.cancel();  // we cannot make this selection without user interaction
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DashboardScreen.showInstallingDllsDialog(msg).then((choice) {
              if (choice == null) {
                self.cancel();
              } else {
                self._ws.sink.add(jsonEncode(msg.responses[choice]));
              }
            });
          });
        }
      },
      '/progress/download/started': (self, data) {
        final msg = ProgressDownloadStarted.fromJson(data);
        self.downloads.add(msg.url);
        self.downloadsCompleted = false;
      },
      '/progress/download/length': (self, data) {
        final msg = ProgressDownloadLength.fromJson(data);
        self.downloadLength[msg.url] = msg.length;
      },
      '/progress/download/intermediate': (self, data) {
        final msg = ProgressDownloadIntermediate.fromJson(data);
        self.downloadDownloaded[msg.url] = msg.downloaded;
      },
      '/progress/download/finished': (self, data) {
        final msg = ProgressDownloadFinished.fromJson(data);
        self.downloadSuccess[msg.url] = msg.success;
        self.downloadsFailed |= !msg.success;
        self._downloadsCompletedOnNextNonProgressDownloadMsg = true;
      },
      '/progress/update/extraction': (self, data) {  // not relevant for isBackground
        final msg = ProgressUpdateExtraction.fromJson(data);
        self.extractionProgress = msg;
        if (msg.progress.numerator == msg.progress.denominator) {
          self._extractionFinishedOnNextMsg = true;
        }
      },
      '/result': (self, data) {
        self.status = UpdateStatus.finished;
      },
    });

  void handleMessage(Map<String, dynamic> data) {
    if (data case {'\$type': String type}) {
      if (_extractionFinishedOnNextMsg) {
        extractionFinished = true;
        _extractionFinishedOnNextMsg = false;
      }
      if (_downloadsCompletedOnNextNonProgressDownloadMsg) {
        if (!type.startsWith('/progress/download/')) {
          downloadsCompleted = true;
        }  // otherwise downloads are still ongoing
        _downloadsCompletedOnNextNonProgressDownloadMsg = false;
      }

      final handler = messageHandlers[type];
      if (handler != null) {
        handler(this, data);
      } else if (type.startsWith('/error/')) {
        err = ApiError(data);
        status = UpdateStatus.finishedWithError;
      } else {
        debugPrint('Message type not implemented: $data');
        err = ApiError.unexpected("Unexpected error: API message type not implemented", '$data');
        cancel();
      }
      notifyListeners();
    } else {
      debugPrint('Unexpected message format: $data');
      err = ApiError.unexpected("Unexpected error: unknown API message format", '$data');
      cancel();
    }
  }
}
