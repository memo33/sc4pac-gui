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

class Api {
  static const rootUrl = 'http://localhost:51515';
  static const wsUrl = 'ws://localhost:51515';

  static Future<Map<String, dynamic>> info(BareModule module) async {
    final response = await http.get(Uri.parse('$rootUrl/packages.info?pkg=$module')); // TODO url encode
    if (response.statusCode == 200) {
      return jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>;
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static Future<List<Map<String, dynamic>>> search(String query) async {
    final response = await http.get(Uri.parse('$rootUrl/packages.search?q=$query')); // TODO url encode
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonUtf8Decode(response.bodyBytes) as List<dynamic>);
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static Future<void> add(BareModule module) async {
    final response = await http.post(Uri.parse('$rootUrl/plugins.add'),
      body: jsonUtf8Encode([module.toString()]),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static Future<void> remove(BareModule module) async {
    final response = await http.post(Uri.parse('$rootUrl/plugins.remove'),
      body: jsonUtf8Encode([module.toString()]),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static Future<List<InstalledListItem>> installed() async {
    final response = await http.get(Uri.parse('$rootUrl/plugins.installed.list'));
    if (response.statusCode == 200) {
      return (jsonUtf8Decode(response.bodyBytes) as List<dynamic>).map((m) => InstalledListItem.fromJson(m as Map<String, dynamic>)).toList();
    } else {
      throw ApiError(jsonUtf8Decode(response.bodyBytes) as Map<String, dynamic>);
    }
  }

  static WebSocketChannel update() {
    final ws = WebSocketChannel.connect(Uri.parse('$wsUrl/update'));
    return ws;
  }

  static Future<Map<String, dynamic>> serverStatus() async {
    final response = await http.get(Uri.parse('$rootUrl/server.status'));
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
