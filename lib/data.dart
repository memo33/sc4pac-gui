// This file contains data classes that are serializable from JSON
// and are used with the API.
// The serialization code is auto-generated in `data.g.dart`.
import 'package:json_annotation/json_annotation.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cryptography/cryptography.dart';
import 'package:equatable/equatable.dart';
import 'dart:convert';

part 'data.g.dart';  // access private members in generated code

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

@JsonSerializable()
class ProgressUpdateExtraction {
  final String package;
  final ({int numerator, int denominator}) progress;
  const ProgressUpdateExtraction(this.package, this.progress);
  factory ProgressUpdateExtraction.fromJson(Map<String, dynamic> json) => _$ProgressUpdateExtractionFromJson(json);
}

@JsonSerializable()
class UpdateInitialArguments {
  final List<String> choices;
  final String token;
  final Map<String, dynamic> responses;
  const UpdateInitialArguments(this.choices, this.token, this.responses);
  factory UpdateInitialArguments.fromJson(Map<String, dynamic> json) => _$UpdateInitialArgumentsFromJson(json);
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
class ChoiceUpdateVariantInfoValue {
  final String? description;
  final Map<String, String> valueDescriptions;
  @JsonKey(name: 'default')
  final List<String> defaultValue;
  const ChoiceUpdateVariantInfoValue({this.description, this.valueDescriptions = const {}, this.defaultValue = const []});
  factory ChoiceUpdateVariantInfoValue.fromJson(Map<String, dynamic> json) => _$ChoiceUpdateVariantInfoValueFromJson(json);
}
@JsonSerializable()
class ChoiceUpdateVariant {
  final String package;
  final String variantId;
  final List<String> choices;
  final ChoiceUpdateVariantInfoValue info;
  final List<String> previouslySelectedValue;
  final List<String> importedValues;
  final Map<String, dynamic> responses;
  const ChoiceUpdateVariant(this.package, this.variantId, this.choices, this.info, this.responses, {this.previouslySelectedValue = const [], this.importedValues = const []});
  factory ChoiceUpdateVariant.fromJson(Map<String, dynamic> json) => _$ChoiceUpdateVariantFromJson(json);
}

@JsonSerializable()
class ConfirmationRemoveUnresolvablePackages {
  final List<String> packages;
  final List<String> choices;
  final Map<String, dynamic> responses;
  const ConfirmationRemoveUnresolvablePackages(this.packages, this.choices, this.responses);
  factory ConfirmationRemoveUnresolvablePackages.fromJson(Map<String, dynamic> json) => _$ConfirmationRemoveUnresolvablePackagesFromJson(json);
}

@JsonSerializable()
class ChoiceRemoveConflictingPackages {
  final List<String> conflict;  // 2 pkgs
  final List<List<String>> explicitPackages;  // 2 lists of pkgs
  final List<String> choices;
  final Map<String, dynamic> responses;
  const ChoiceRemoveConflictingPackages(this.conflict, this.explicitPackages, this.choices, this.responses);
  factory ChoiceRemoveConflictingPackages.fromJson(Map<String, dynamic> json) => _$ChoiceRemoveConflictingPackagesFromJson(json);
}

@JsonSerializable()
class DownloadFailedSelectMirror {
  final String url;
  final Map<String, dynamic> reason;  // ApiError
  final List<String> choices;
  final String token;
  final Map<String, dynamic> responses;
  const DownloadFailedSelectMirror(this.url, this.reason, this.choices, this.token, this.responses);
  factory DownloadFailedSelectMirror.fromJson(Map<String, dynamic> json) => _$DownloadFailedSelectMirrorFromJson(json);
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
class ProgressDownloadIntermediate {
  final String url;
  final int downloaded;  // String in JSON if > 2^53 --> unlikely
  ProgressDownloadIntermediate(this.url, this.downloaded);
  factory ProgressDownloadIntermediate.fromJson(Map<String, dynamic> json) => _$ProgressDownloadIntermediateFromJson(json);
}

@JsonSerializable()
class ProgressDownloadFinished {
  final String url;
  final bool success;
  ProgressDownloadFinished(this.url, this.success);
  factory ProgressDownloadFinished.fromJson(Map<String, dynamic> json) => _$ProgressDownloadFinishedFromJson(json);
}

typedef ConfirmationInstallingDllsItem = ({
  String dll,
  ({String sha256}) checksum,
  String url,
  String package,
  String packageVersion,
  String assetMetadataUrl,
  String packageMetadataUrl,
});

@JsonSerializable()
class ConfirmationInstallingDlls {
  final String description;
  final List<ConfirmationInstallingDllsItem> dllsInstalled;
  final List<String> choices;
  final Map<String, dynamic> responses;
  const ConfirmationInstallingDlls(this.description, this.dllsInstalled, this.choices, this.responses);
  factory ConfirmationInstallingDlls.fromJson(Map<String, dynamic> json) => _$ConfirmationInstallingDllsFromJson(json);
}

@JsonSerializable()
class PromptOpenPackage {
  final List<({String package, String channelUrl})> packages;
  PromptOpenPackage(this.packages);
  factory PromptOpenPackage.fromJson(Map<String, dynamic> json) => _$PromptOpenPackageFromJson(json);
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

typedef ProfilesListItem = ({String id, String name, String? pluginsRoot});
@JsonSerializable()
class Profiles {
  final List<ProfilesListItem> profiles;
  final List<String> currentProfileId;
  final String profilesDir;
  Profiles(this.profiles, this.currentProfileId, this.profilesDir);
  factory Profiles.fromJson(Map<String, dynamic> json) => _$ProfilesFromJson(json);
  ProfilesListItem? currentProfile() {
    final idx = profiles.indexWhere((p) => currentProfileId.contains(p.id));
    return idx == -1 ? null : profiles[idx];
  }
}

@JsonSerializable()
class ChannelStats {
  final int totalPackageCount;
  final List<({String category, int count})> categories;
  ChannelStats(this.totalPackageCount, this.categories);
  factory ChannelStats.fromJson(Map<String, dynamic> json) => _$ChannelStatsFromJson(json);
}

@JsonSerializable()
class ChannelStatsAll {
  final ChannelStats combined;
  final List<({String url, String? channelLabel, ChannelStats stats})> channels;
  ChannelStatsAll(this.combined, this.channels);
  factory ChannelStatsAll.fromJson(Map<String, dynamic> json) => _$ChannelStatsAllFromJson(json);
}

@JsonSerializable()
class InstalledStatus {
  final bool explicit;
  final ({String version, Map<String, String> variant, DateTime installedAt, DateTime updatedAt, bool? reinstall})? installed;
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
  late final BareModule module = BareModule.parse(package);
  final int relevance;
  final String summary;
  final InstalledStatus? status;
  PackageSearchResultItem(this.package, this.relevance, this.summary, this.status);
  factory PackageSearchResultItem.fromJson(Map<String, dynamic> json) => _$PackageSearchResultItemFromJson(json);
}

@JsonSerializable()
class PackageSearchResult {
  final List<PackageSearchResultItem> packages;
  final int notFoundPackageCount;
  final int notFoundExternalIdCount;
  final ChannelStats? stats;
  const PackageSearchResult(this.packages, {this.notFoundPackageCount = 0, this.notFoundExternalIdCount = 0, this.stats});
  factory PackageSearchResult.fromJson(Map<String, dynamic> json) => _$PackageSearchResultFromJson(json);
  static const empty = PackageSearchResult([]);
}

@JsonSerializable()
class PluginsSearchResultItem {
  final String package;
  late final BareModule module = BareModule.parse(package);
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

  static final PackageInfoResult notFound = PackageInfoResult((statuses: const {}), const {});
}

@JsonSerializable()
class AuthItem {
  static const simtropolisDomain = "community.simtropolis.com";
  final String domain;
  @JsonKey(
    toJson: _base64Encode,
    fromJson: _base64Decode,
  )
  final List<int>? tokenBytes;
  late final String? token = tokenBytes != null ? _deobfuscateTokenSync(tokenBytes!) : null;
  AuthItem({required this.domain, this.tokenBytes});
  factory AuthItem.fromJson(Map<String, dynamic> json) => _$AuthItemFromJson(json);
  Map<String, dynamic> toJson() => _$AuthItemToJson(this);
  bool isSimtropolisToken() => domain == simtropolisDomain && token?.isNotEmpty == true;

  static String? _base64Encode(List<int>? bytes) => bytes != null ? base64.encode(bytes) : null;
  static List<int>? _base64Decode(String? text) => text != null ? base64.decode(text) : null;

  // We merely obfuscate the stored token to prevent *untargeted* malware from reading the token from disk.
  // There is no need to keep this secret from the end user, so we store the plain key here.
  static SecretKeyData _createKey() =>
    SecretKeyData([
      0x30,0x1f,0x51,0xbf,0xd0,0xf3,0xa8,0x4c,0x0c,0xbd,0x11,0x23,0x5a,0x91,0xb2,0xf3,
      0x4d,0x06,0x5d,0xe8,0xe8,0x2e,0xfc,0x6c,0x38,0xa6,0x7c,0xc4,0xeb,0x22,0x19,0x3b,
    ]);

  static Future<List<int>> obfuscateToken(String token) async {
    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encryptString(token, secretKey: _createKey());
    return secretBox.concatenation();
  }

  static String? _deobfuscateTokenSync(List<int> concatenatedBytes) {
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
  final bool refreshChannels;
  SettingsData({this.auth = const [], this.refreshChannels = false});
  SettingsData withAuth({List<AuthItem>? auth}) {
    return auth == null ? this : SettingsData(auth: auth, refreshChannels: refreshChannels);
  }
  SettingsData withRefreshChannels(bool refreshChannels) {
    return refreshChannels == this.refreshChannels ? this : SettingsData(auth: auth, refreshChannels: refreshChannels);
  }
  factory SettingsData.fromJson(Map<String, dynamic> json) => _$SettingsDataFromJson(json);
  Map<String, dynamic> toJson() => _$SettingsDataToJson(this);

  late final AuthItem? stAuth = switch(auth.where((a) => a.isSimtropolisToken())) {
    final auth2 => auth2.isNotEmpty ? auth2.first : null,
  };
}

@JsonSerializable()
class VariantsList {
  final Map<String, ({String value, bool unused})> variants;
  VariantsList(this.variants);
  factory VariantsList.fromJson(Map<String, dynamic> json) => _$VariantsListFromJson(json);
}

@JsonSerializable(includeIfNull: false)
class ExportData {
  final List<String>? explicit;
  Map<String, String>? variants;
  final List<String>? channels;
  final ({Map<String, String>? variant, List<String>? channels})? config;  // `config` is not intended for ordinary use, only as fallback for compatibility with sc4pac-plugins.json file
  ExportData({this.explicit, this.variants, this.channels, this.config});
  factory ExportData.fromJson(Map<String, dynamic> json) => _$ExportDataFromJson(json);
  Map<String, dynamic> toJson() => _$ExportDataToJson(this);
}

@JsonSerializable()
class RepairPlan {
  final List<String> incompletePackages;
  final List<String> orphanFiles;
  RepairPlan(this.incompletePackages, this.orphanFiles);
  factory RepairPlan.fromJson(Map<String, dynamic> json) => _$RepairPlanFromJson(json);
  Map<String, dynamic> toJson() => _$RepairPlanToJson(this);
  bool isUpToDate() => incompletePackages.isEmpty && orphanFiles.isEmpty;
}
