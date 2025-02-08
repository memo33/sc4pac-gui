import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:io';
import 'dart:async';
import 'data.dart';

final Converter<List<int>, Object?> _jsonUtf8Decoder = const Utf8Decoder().fuse(const JsonDecoder());
final Converter<Object?, List<int>> _jsonUtf8Encoder = JsonUtf8Encoder();
final Object? Function(List<int> bytes) jsonUtf8Decode = _jsonUtf8Decoder.convert;
final List<int> Function(Object? o) jsonUtf8Encode = _jsonUtf8Encoder.convert;

class BareModule extends Equatable {
  final String group, name;
  const BareModule(this.group, this.name);
  @override toString() => '$group:$name';
  String toJson() => toString();
  @override List<Object> get props => [group, name];

  factory BareModule.parse(String s) {
    final idx = s.indexOf(':');
    return idx == -1 ? BareModule('unknown', s) : BareModule(s.substring(0, idx), s.substring(idx + 1));
  }

  static int compareAlphabetically(BareModule a, BareModule b) {
    final result = a.group.compareTo(b.group);
    return result == 0 ? a.name.compareTo(b.name) : result;
  }
}

class ApiError {
  final String type, title, detail;
  final Map<String, dynamic> json;
  ApiError(this.json) :
    type = json['\$type'] as String,
    title = json['title'] as String,
    detail = json['detail'] as String;
  factory ApiError.unexpected(String title, String detail) => ApiError({'\$type': '/error/unexpected', 'title': title, 'detail': detail});
  factory ApiError.from(Object err) {
    return err is ApiError ? err : ApiError.unexpected('Unexpected error', err.toString());
  }
}

enum ServerStatus { launching, listening, terminated }

// server is launched from desktop GUI, but not from webapp
class Sc4pacServer {
  final String cliDir;
  final String? profilesDir;
  final int port;
  ServerStatus status = ServerStatus.launching;
  late final Future<Process> _process;
  late final Future<bool> ready;  // true once server listens, false if launching server did not work (This future never fails)
  ApiError? launchError;
  List<String> stderrBuffer = [];

  static const int _javaNotFound = 55;
  static const int _portOccupied = 56;

  Sc4pacServer({required this.cliDir, required this.profilesDir, required this.port}) {
    const readyTag = "[LISTENING]";
    final completer = Completer<bool>();
    const splitter = LineSplitter();
    ready = completer.future;
    final cliExePath = Platform.isWindows ? "$cliDir/sc4pac.bat" : "$cliDir/sc4pac";
    if (!File(cliExePath).existsSync()) {
      launchError = ApiError.unexpected("Failed to launch the local sc4pac server, as the sc4pac CLI executable was not found in the expected location.", cliExePath);
      status = ServerStatus.terminated;
      completer.complete(false);
    } else {
      _process = Process.start(
        cliExePath,
        [
          "server",
          "--port", port.toString(),
          if (profilesDir != null)
            ...["--profiles-dir", profilesDir!],
          "--auto-shutdown",
          "--startup-tag", readyTag,
        ],
      )
      ..then((process) {
        stdout.writeln("Sc4pac server PID: ${process.pid}");
        // it's important to consume both stdout and stderr to avoid freezes
        process.stdout.transform(utf8.decoder).forEach((String lines) {
          if (status == ServerStatus.launching && lines.contains(readyTag)) {
            status = ServerStatus.listening;
            completer.complete(true);
          }
          for (final line in splitter.convert(lines)) {
            stdout.writeln("[SERVER] $line");
          }
        });
        Future<void> stderrTerminated = process.stderr.transform(utf8.decoder).forEach((String lines) {
          stderrBuffer.add(lines);
          if (stderrBuffer.length >= 10) {
            stderrBuffer = stderrBuffer.sublist(5);
          }
          for (final line in splitter.convert(lines)) {
            stdout.writeln("[SERVER:err] $line");
          }
          if (!completer.isCompleted && lines.contains("UnsupportedClassVersion")) {
            launchError ??= ApiError.unexpected(
              "The Java version installed on your system is too old. Install a more recent version of Java.",
              lines,
            );
          }
        });
        process.exitCode.then((exitCode) async {
          status = ServerStatus.terminated;
          if (exitCode == _javaNotFound) {
            const msg = "Java could not be found. Please install a Java Runtime Environment and make sure it is added to your PATH environment variable during the installation.";
            stdout.writeln(msg);
            launchError ??= ApiError.unexpected(msg, "");
          } else if (exitCode == _portOccupied) {
            final msg = """Another program is already running on port $port. Please quit the other program – likely another instance of sc4pac.""";
            final detail = """Alternatively, launch the sc4pac GUI on a different port (using the "--port" launch option) or connect to an existing sc4pac process on port $port (using the "--launch-server=false" option)."""
                """\n(For technical reasons, this error can also occur if you open and close the sc4pac GUI in quick succession. In this case, just wait for 20 seconds before re-opening the application again.)""";
            stdout.writeln("$msg $detail");
            launchError ??= ApiError.unexpected(msg, detail);
          } else {
            stdout.writeln("Sc4pac server exited with code $exitCode");
            if (!completer.isCompleted) {  // launching failed
              await stderrTerminated.catchError((_) {});
              launchError ??= ApiError.unexpected("Launching the local sc4pac server failed.", stderrBuffer.join("\n"));
            }
          }
        }).whenComplete(() {  // whenComplete runs regardless of whether future succeeded or failed
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        });
      }, onError: (err) {
        stderr.writeln("Failed to launch server: $err");  // failed to launch server, probably because cliDir is wrong
        status = ServerStatus.terminated;
        completer.complete(false);
        launchError ??= ApiError.unexpected("Failed to launch local sc4pac server.", err.toString());
      });
    }
  }
}

enum ClientStatus { connecting, connected, serverNotRunning, lostConnection }

// TODO refactor to make use of http.Client for keep-alive connections
class Sc4pacClient /*extends ChangeNotifier*/ {
  static const defaultPort = 51515;
  final String authority;
  final String wsUrl;
  final WebSocketChannel connection;
  ClientStatus status = ClientStatus.connecting;
  final void Function() onConnectionLost;
  final void Function(List<BareModule>, Set<String> channelUrls) openPackages;

  Sc4pacClient(this.authority, {required this.onConnectionLost, required this.openPackages}) :
    wsUrl = 'ws://$authority',
    connection = serverConnect('ws://$authority')  // TODO appears to unregister automatically when application exits
  {
    connection.ready
      .then((_) {
        status = ClientStatus.connected;
        // notifyListeners();
        // next monitor potential closing of the websocket
        connection.stream
          .map((data) => jsonDecode(data as String) as Map<String, dynamic>)
          .forEach(handleMessage)
          .then((_) {
            status = ClientStatus.lostConnection;
            // notifyListeners();
            onConnectionLost();
          }, onError: (e) {
            debugPrint("Unexpected websocket stream error: $e");  // should not happen
          });
      }, onError: (_) {  // in this case, we must not listen to the stream
        status = ClientStatus.serverNotRunning;
        // notifyListeners();
      });
  }

  void handleMessage(Map<String, dynamic> data) {
    if (data case {'\$type': String type}) {
      if (type == '/prompt/open/package') {
        final msg = PromptOpenPackage.fromJson(data);
        if (msg.packages.isNotEmpty) {
          openPackages(
            msg.packages.map((item) => BareModule.parse(item.package)).toList(),
            msg.packages.map((item) => item.channelUrl).toSet(),
          );
        }
      } else {
        debugPrint('Message type not implemented: $data');
      }
    } else {
      debugPrint('Unexpected message format: $data');
    }
  }

  Future<({bool initialized, Map<String, dynamic> data})> profileRead({required String profileId}) async {
    final response = await http.get(Uri.http(authority, '/profile.read', {'profile': profileId}));
    final data = jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>;
    if (response.statusCode == 409 && data['\$type'] == '/error/profile-not-initialized'
      || response.statusCode == 200) {
      return (
        initialized: response.statusCode == 200,
        data: data,
      );
    } else {
      throw ApiError(data);
    }
  }

  Future<Map<String, dynamic>> profileInit({required String profileId, required ({String plugins, String cache}) paths}) async {
    final response = await http.post(Uri.http(authority, '/profile.init', {'profile': profileId}),
      body: jsonUtf8Encode({'plugins': paths.plugins, 'cache': paths.cache, 'temp': "../temp"}),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>;
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  Future<PackageInfoResult> info(BareModule module, {required String profileId}) async {
    final response = await http.get(Uri.http(authority, '/packages.info', {'pkg': module.toString(), 'profile': profileId}));
    if (response.statusCode == 200) {
      return PackageInfoResult.fromJson(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    } else if (response.statusCode == 404) {
      return PackageInfoResult.notFound;
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  Future<List<PackageSearchResultItem>> search(String query, {String? category, List<String> notCategories = const [], String? channel, bool ignoreInstalled = false, required String profileId}) async {
    final response = await http.get(Uri.http(authority, '/packages.search', {
      'q': query,
      'profile': profileId,
      if (category?.isNotEmpty == true) 'category': category,
      if (notCategories.isNotEmpty) 'notCategory': notCategories,
      if (channel?.isNotEmpty == true) 'channel': channel,
      if (ignoreInstalled) 'ignoreInstalled': null,
    }));
    if (response.statusCode == 200) {
      return (jsonUtf8Decode(response.bodyBytes) as List<dynamic>)
          .map((item) => PackageSearchResultItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  Future<List<PackageSearchResultItem>> searchById(List<BareModule> packages, {required String profileId}) async {
    final response = await http.post(Uri.http(authority, '/packages.search.id', {'profile': profileId}),
      body: jsonUtf8Encode({'packages': packages}),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return (jsonUtf8Decode(response.bodyBytes) as List<dynamic>)
          .map((item) => PackageSearchResultItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  Future<PluginsSearchResult> pluginsSearch(String query, {String? category, required String profileId}) async {
    final response = await http.get(Uri.http(authority, '/plugins.search', {
      'q': query,
      'profile': profileId,
      if (category != null && category.isNotEmpty) 'category': category
    }));
    if (response.statusCode == 200) {
      return PluginsSearchResult.fromJson(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  Future<void> add(BareModule module, {required String profileId}) async {
    final response = await http.post(Uri.http(authority, '/plugins.add', {'profile': profileId}),
      body: jsonUtf8Encode([module.toString()]),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  Future<void> remove(BareModule module, {required String profileId}) async {
    final response = await http.post(Uri.http(authority, '/plugins.remove', {'profile': profileId}),
      body: jsonUtf8Encode([module.toString()]),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  Future<List<InstalledListItem>> installed({required String profileId}) async {
    final response = await http.get(Uri.http(authority, '/plugins.installed.list', {'profile': profileId}));
    if (response.statusCode == 200) {
      return (jsonUtf8Decode(response.bodyBytes) as List<dynamic>).map((m) => InstalledListItem.fromJson(m as Map<String, dynamic>)).toList();
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  Future<Map<String, dynamic>> variantsList({required String profileId}) async {
    final response = await http.get(Uri.http(authority, '/variants.list', {'profile': profileId}));
    if (response.statusCode == 200) {
      return jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>;
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  Future<void> variantsReset(List<String> variants, {required String profileId}) async {
    final response = await http.post(Uri.http(authority, '/variants.reset', {'profile': profileId}),
      body: jsonUtf8Encode(variants),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  Future<List<String>> channelsList({required String profileId}) async {
    final response = await http.get(Uri.http(authority, '/channels.list', {'profile': profileId}));
    if (response.statusCode == 200) {
      return List<String>.from(jsonUtf8Decode(response.bodyBytes) as List<dynamic>);
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  Future<void> channelsSet(List<String> urls, {required String profileId}) async {
    final response = await http.post(Uri.http(authority, '/channels.set', {'profile': profileId}),
      body: jsonUtf8Encode(urls),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  Future<ChannelStatsAll> channelsStats({required String profileId}) async {
    final response = await http.get(Uri.http(authority, '/channels.stats', {'profile': profileId}));
    if (response.statusCode == 200) {
      return ChannelStatsAll.fromJson(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  WebSocketChannel update({required String profileId, required String? simtropolisCookie, required bool refreshChannels}) {
    final ws = WebSocketChannel.connect(Uri.parse('$wsUrl/update').replace(queryParameters: {
      'profile': profileId,
      if (simtropolisCookie != null) 'simtropolisCookie': simtropolisCookie,
      if (refreshChannels) 'refreshChannels': null,
    }));
    return ws;
  }

  static Future<Map<String, dynamic>> serverStatus(String authority) async {
    final response = await http.get(Uri.http(authority, '/server.status'));
    if (response.statusCode == 200) {
      try {
        return jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>;
      } on FormatException {
        throw ApiError.unexpected("Cannot connect to sc4pac server", "http://$authority/server.status");
      }
    } else {
      // throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
      throw ApiError.unexpected("Cannot connect to sc4pac server", "http://$authority/server.status");
    }
  }

  static WebSocketChannel serverConnect(String wsUrl) {
    final ws = WebSocketChannel.connect(Uri.parse('$wsUrl/server.connect'));
    return ws;
  }

  Future<Profiles> profiles() async {
    final response = await http.get(Uri.http(authority, '/profiles.list'));
    if (response.statusCode == 200) {
      return Profiles.fromJson(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  Future<({String id, String name})> addProfile(String name) async {
    final response = await http.post(Uri.http(authority, '/profiles.add'),
      body: jsonUtf8Encode({'name': name}),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final m = jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>;
      if (m case {'id': String id, 'name': String name}) {
        return (id: id, name: name);
      }
    }
    throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
  }

  Future<void> switchProfile(String profileId) async {
    final response = await http.post(Uri.http(authority, '/profiles.switch'),
      body: jsonUtf8Encode({'id': profileId}),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  Future<SettingsData> getSettings() async {
    final response = await http.get(Uri.http(authority, '/settings.all.get'));
    if (response.statusCode == 200) {
      return SettingsData.fromJson(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  Future<void> setSettings(SettingsData settingsData) async {
    final response = await http.post(Uri.http(authority, '/settings.all.set'),
      body: jsonUtf8Encode(settingsData),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  // this redirection via API solves CORS errors in web browser (canvaskit renderer only)
  Uri redirectImageUrl(String url) {
    return Uri.http(authority, '/image.fetch', {'url': url});
  }

}
