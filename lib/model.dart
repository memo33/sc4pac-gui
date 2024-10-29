import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'data.dart';

final Converter<List<int>, Object?> _jsonUtf8Decoder = const Utf8Decoder().fuse(const JsonDecoder());
final Converter<Object?, List<int>> _jsonUtf8Encoder = JsonUtf8Encoder();
final Object? Function(List<int> bytes) jsonUtf8Decode = _jsonUtf8Decoder.convert;
final List<int> Function(Object? o) jsonUtf8Encode = _jsonUtf8Encoder.convert;

class BareModule extends Equatable {
  final String group, name;
  const BareModule(this.group, this.name);
  @override toString() => '$group:$name';
  @override List<Object> get props => [group, name];

  factory BareModule.parse(String s) {
    final idx = s.indexOf(':');
    return idx == -1 ? BareModule('unknown', s) : BareModule(s.substring(0, idx), s.substring(idx + 1));
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

// TODO refactor to make use of http.Client for keep-alive connections
class Api {
  static const host = 'localhost:51515';  // TODO make port configurable
  static const wsUrl = 'ws://$host';

  static Future<({bool initialized, Map<String, dynamic> data})> profileRead({required String profileId}) async {
    final response = await http.get(Uri.http(host, '/profile.read', {'profile': profileId}));
    if (response.statusCode == 409 || response.statusCode == 200) {
      return (
        initialized: response.statusCode == 200,
        data: jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>,
      );
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static Future<Map<String, dynamic>> profileInit({required String profileId, required ({String plugins, String cache}) paths}) async {
    final response = await http.post(Uri.http(host, '/profile.init', {'profile': profileId}),
      body: jsonUtf8Encode({'plugins': paths.plugins, 'cache': paths.cache}),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>;
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static Future<PackageInfoResult> info(BareModule module, {required String profileId}) async {
    final response = await http.get(Uri.http(host, '/packages.info', {'pkg': module.toString(), 'profile': profileId}));
    if (response.statusCode == 200) {
      return PackageInfoResult.fromJson(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static Future<List<PackageSearchResultItem>> search(String query, {String? category, required String profileId}) async {
    final response = await http.get(Uri.http(host, '/packages.search', {
      'q': query,
      'profile': profileId,
      if (category != null && category.isNotEmpty) 'category': category
    }));
    if (response.statusCode == 200) {
      return (jsonUtf8Decode(response.bodyBytes) as List<dynamic>)
          .map((item) => PackageSearchResultItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static Future<PluginsSearchResult> pluginsSearch(String query, {String? category, required String profileId}) async {
    final response = await http.get(Uri.http(host, '/plugins.search', {
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

  static Future<void> add(BareModule module, {required String profileId}) async {
    final response = await http.post(Uri.http(host, '/plugins.add', {'profile': profileId}),
      body: jsonUtf8Encode([module.toString()]),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static Future<void> remove(BareModule module, {required String profileId}) async {
    final response = await http.post(Uri.http(host, '/plugins.remove', {'profile': profileId}),
      body: jsonUtf8Encode([module.toString()]),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static Future<List<InstalledListItem>> installed({required String profileId}) async {
    final response = await http.get(Uri.http(host, '/plugins.installed.list', {'profile': profileId}));
    if (response.statusCode == 200) {
      return (jsonUtf8Decode(response.bodyBytes) as List<dynamic>).map((m) => InstalledListItem.fromJson(m as Map<String, dynamic>)).toList();
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static Future<Map<String, dynamic>> variantsList({required String profileId}) async {
    final response = await http.get(Uri.http(host, '/variants.list', {'profile': profileId}));
    if (response.statusCode == 200) {
      return jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>;
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static Future<void> variantsReset(List<String> variants, {required String profileId}) async {
    final response = await http.post(Uri.http(host, '/variants.reset', {'profile': profileId}),
      body: jsonUtf8Encode(variants),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static Future<List<String>> channelsList({required String profileId}) async {
    final response = await http.get(Uri.http(host, '/channels.list', {'profile': profileId}));
    if (response.statusCode == 200) {
      return List<String>.from(jsonUtf8Decode(response.bodyBytes) as List<dynamic>);
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static Future<void> channelsSet(List<String> urls, {required String profileId}) async {
    final response = await http.post(Uri.http(host, '/channels.set', {'profile': profileId}),
      body: jsonUtf8Encode(urls),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static Future<ChannelStats> channelsStats({required String profileId}) async {
    final response = await http.get(Uri.http(host, '/channels.stats', {'profile': profileId}));
    if (response.statusCode == 200) {
      return ChannelStats.fromJson(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static WebSocketChannel update({required String profileId}) {
    final ws = WebSocketChannel.connect(Uri.parse('$wsUrl/update?profile=$profileId'));
    return ws;
  }

  static Future<Map<String, dynamic>> serverStatus() async {
    final response = await http.get(Uri.http(host, '/server.status'));
    if (response.statusCode == 200) {
      return jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>;
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static WebSocketChannel serverConnect() {
    final ws = WebSocketChannel.connect(Uri.parse('$wsUrl/server.connect'));
    return ws;
  }

  static Future<Profiles> profiles() async {
    final response = await http.get(Uri.http(host, '/profiles.list'));
    if (response.statusCode == 200) {
      return Profiles.fromJson(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static Future<({String id, String name})> addProfile(String name) async {
    final response = await http.post(Uri.http(host, '/profiles.add'),
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

}

enum ClientStatus { connecting, connected, serverNotRunning, lostConnection }

class Sc4pacClient extends ChangeNotifier {
  final WebSocketChannel connection = Api.serverConnect();  // TODO appears to unregister automatically when application exits
  ClientStatus status = ClientStatus.connecting;

  Sc4pacClient() {
    connection.ready
      .then((_) {
        status = ClientStatus.connected;
        notifyListeners();
        // next monitor potential closing of the websocket
        connection.stream.drain<String>('done')
          .then((_) {
            status = ClientStatus.lostConnection;
            notifyListeners();
          }, onError: (e) {
            debugPrint("Unexpected websocket stream error: $e");  // should not happen
          });
      }, onError: (_) {  // in this case, we must not listen to the stream
        status = ClientStatus.serverNotRunning;
        notifyListeners();
      });
  }
}
