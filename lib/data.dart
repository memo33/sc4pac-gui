// This file contains data classes that are serializable from JSON
// and are used with the API.
// The serialization code is auto-generated in `data.g.dart`.
import 'package:json_annotation/json_annotation.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cryptography/cryptography.dart';
import 'dart:convert';

part 'data.g.dart';  // access private members in generated code

@JsonSerializable()
class ProgressUpdateExtraction {
  final String package;
  final ({int numerator, int denominator}) progress;
  const ProgressUpdateExtraction(this.package, this.progress);
  factory ProgressUpdateExtraction.fromJson(Map<String, dynamic> json) => _$ProgressUpdateExtractionFromJson(json);
}

@JsonSerializable()
class UpdatePlan {
  final List<({String package, String version, Map<String, String> variant})> toRemove;
  final List<({String package, String version, Map<String, String> variant})> toInstall;
  final List<String> choices;
  final Map<String, dynamic> responses;

  @JsonKey(includeFromJson: false, includeToJson: false)
  late final Map<String, ({String? versionFrom, String? versionTo, Map<String, String>? variantFrom, Map<String, String>? variantTo})> changes;

  UpdatePlan(this.toRemove, this.toInstall, this.choices, this.responses) {
    changes = {for (final pkg in toRemove) pkg.package: (versionFrom: pkg.version, versionTo: null, variantFrom: pkg.variant, variantTo: null)};
    for (final pkg in toInstall) {
      final c = changes[pkg.package];
      changes[pkg.package] = (versionFrom: c?.versionFrom, versionTo: pkg.version, variantFrom: c?.variantFrom, variantTo: pkg.variant);
    }
  }

  factory UpdatePlan.fromJson(Map<String, dynamic> json) => _$UpdatePlanFromJson(json);

  bool get nothingToDo => toRemove.isEmpty && toInstall.isEmpty;
}

@JsonSerializable()
class ConfirmationUpdateWarnings {
  final Map<String, List<String>> warnings;
  final List<String> choices;
  final Map<String, dynamic> responses;
  const ConfirmationUpdateWarnings(this.warnings, this.choices, this.responses);
  factory ConfirmationUpdateWarnings.fromJson(Map<String, dynamic> json) => _$ConfirmationUpdateWarningsFromJson(json);
}

@JsonSerializable()
class ChoiceUpdateVariant {
  final String package;
  final String label;
  final List<String> choices;
  final Map<String, String> descriptions;
  final Map<String, dynamic> responses;
  const ChoiceUpdateVariant(this.package, this.label, this.choices, this.descriptions, this.responses);
  factory ChoiceUpdateVariant.fromJson(Map<String, dynamic> json) => _$ChoiceUpdateVariantFromJson(json);
}

@JsonSerializable()
class ProgressDownloadStarted {
  final String url;
  ProgressDownloadStarted(this.url);
  factory ProgressDownloadStarted.fromJson(Map<String, dynamic> json) => _$ProgressDownloadStartedFromJson(json);
}

@JsonSerializable()
class ProgressDownloadLength {
  final String url;
  final int length;  // String in JSON if > 2^53 --> unlikely
  ProgressDownloadLength(this.url, this.length);
  factory ProgressDownloadLength.fromJson(Map<String, dynamic> json) => _$ProgressDownloadLengthFromJson(json);
}

@JsonSerializable()
class ProgressDownloadDownloaded {
  final String url;
  final int downloaded;  // String in JSON if > 2^53 --> unlikely
  ProgressDownloadDownloaded(this.url, this.downloaded);
  factory ProgressDownloadDownloaded.fromJson(Map<String, dynamic> json) => _$ProgressDownloadDownloadedFromJson(json);
}

@JsonSerializable()
class ProgressDownloadFinished {
  final String url;
  final bool success;
  ProgressDownloadFinished(this.url, this.success);
  factory ProgressDownloadFinished.fromJson(Map<String, dynamic> json) => _$ProgressDownloadFinishedFromJson(json);
}

@JsonSerializable()
class InstalledListItem {
  final String package;
  final String version;
  final Map<String, String> variant;
  final bool explicit;
  InstalledListItem(this.package, this.version, this.variant, this.explicit);
  factory InstalledListItem.fromJson(Map<String, dynamic> json) => _$InstalledListItemFromJson(json);
}

@JsonSerializable()
class Profiles {
  final List<({String id, String name})> profiles;
  final List<String> currentProfileId;
  Profiles(this.profiles, this.currentProfileId);
  factory Profiles.fromJson(Map<String, dynamic> json) => _$ProfilesFromJson(json);
}

@JsonSerializable()
class ChannelStats {
  final int totalPackageCount;
  final List<({String category, int count})> categories;
  ChannelStats(this.totalPackageCount, this.categories);
  factory ChannelStats.fromJson(Map<String, dynamic> json) => _$ChannelStatsFromJson(json);
}

@JsonSerializable()
class InstalledStatus {
  final bool explicit;
  final ({String version, Map<String, String> variant, DateTime installedAt, DateTime updatedAt})? installed;
  InstalledStatus(this.explicit, this.installed);
  factory InstalledStatus.fromJson(Map<String, dynamic> json) => _$InstalledStatusFromJson(json);

  String? timeLabel() {
    if (installed != null) {
      final prefix = installed!.installedAt == installed!.updatedAt ? 'installed' : 'updated';
      return "$prefix ${timeago.format(installed!.updatedAt)}";
    } else {
      return null;
    }
  }

  String? timeLabel2() {
    if (installed != null) {
      final String updatedAgo = installed!.updatedAt == installed!.installedAt ? "never" : timeago.format(installed!.updatedAt);
      return "Installed ${timeago.format(installed!.installedAt)}, updated $updatedAgo";
    } else {
      return null;
    }
  }
}

@JsonSerializable()
class PackageSearchResultItem {
  final String package;
  final int relevance;
  final String summary;
  final InstalledStatus? status;
  PackageSearchResultItem(this.package, this.relevance, this.summary, this.status);
  factory PackageSearchResultItem.fromJson(Map<String, dynamic> json) => _$PackageSearchResultItemFromJson(json);
}

@JsonSerializable()
class PluginsSearchResultItem {
  final String package;
  final int relevance;
  final String summary;
  final InstalledStatus status;  // TODO status.installed should not be null
  PluginsSearchResultItem(this.package, this.relevance, this.summary, this.status);
  factory PluginsSearchResultItem.fromJson(Map<String, dynamic> json) => _$PluginsSearchResultItemFromJson(json);
}

@JsonSerializable()
class PluginsSearchResult {
  final ChannelStats stats;
  final List<PluginsSearchResultItem> packages;
  PluginsSearchResult(this.stats, this.packages);
  factory PluginsSearchResult.fromJson(Map<String, dynamic> json) => _$PluginsSearchResultFromJson(json);
}

@JsonSerializable()
class PackageInfoResult {
  final ({Map<String, InstalledStatus> statuses}) local;
  final Map<String, dynamic> remote;
  PackageInfoResult(this.local, this.remote);
  factory PackageInfoResult.fromJson(Map<String, dynamic> json) => _$PackageInfoResultFromJson(json);
}

@JsonSerializable()
class AuthItem {
  static const simtropolisDomain = "community.simtropolis.com";
  final String domain;
  final DateTime? expirationDate;
  bool? get expired => expirationDate?.isBefore(DateTime.now());
  @JsonKey(
    toJson: _base64Encode,
    fromJson: _base64Decode,
  )
  final List<int> cookieBytes;
  late final String? cookie = _deobfuscateCookieSync(cookieBytes);
  AuthItem({required this.domain, required this.cookieBytes, this.expirationDate});
  factory AuthItem.fromJson(Map<String, dynamic> json) => _$AuthItemFromJson(json);
  Map<String, dynamic> toJson() => _$AuthItemToJson(this);
  bool isSimtropolisCookie() => domain == simtropolisDomain && cookie?.isNotEmpty == true;

  static String _base64Encode(List<int> bytes) => base64.encode(bytes);
  static List<int> _base64Decode(String text) => base64.decode(text);

  // We merely obfuscate the stored cookie to prevent *untargeted* malware from reading the cookie from disk.
  // There is no need to keep this secret from the end user, so we store the plain key here.
  static SecretKeyData _createKey() =>
    SecretKeyData([
      0x30,0x1f,0x51,0xbf,0xd0,0xf3,0xa8,0x4c,0x0c,0xbd,0x11,0x23,0x5a,0x91,0xb2,0xf3,
      0x4d,0x06,0x5d,0xe8,0xe8,0x2e,0xfc,0x6c,0x38,0xa6,0x7c,0xc4,0xeb,0x22,0x19,0x3b,
    ]);

  static Future<List<int>> obfuscateCookie(String cookie) async {
    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encryptString(cookie, secretKey: _createKey());
    return secretBox.concatenation();
  }

  static String? _deobfuscateCookieSync(List<int> concatenatedBytes) {
    final algorithm = AesGcm.with256bits().toSync();  // synchronous for simplicity, even though it may be slower
    try {
      final secretBox = SecretBox.fromConcatenation(
        concatenatedBytes,
        nonceLength: algorithm.nonceLength,
        macLength: algorithm.macAlgorithm.macLength,
        copy: false,
      );
      return utf8.decode(algorithm.decryptSync(secretBox, secretKeyData: _createKey()));
    } catch (e) {
      return null;
    }
  }
}

@JsonSerializable()
class SettingsData {
  final List<AuthItem> auth;
  SettingsData({this.auth = const []});
  SettingsData copyWith({List<AuthItem>? auth}) {
    return auth == null ? this : SettingsData(auth: auth);
  }
  factory SettingsData.fromJson(Map<String, dynamic> json) => _$SettingsDataFromJson(json);
  Map<String, dynamic> toJson() => _$SettingsDataToJson(this);

  late final AuthItem? stAuth = switch(auth.where((a) => a.isSimtropolisCookie())) {
    final auth2 => auth2.isNotEmpty ? auth2.first : null,
  };
}
