// This file contains data classes that are serializable from JSON
// and are used with the API.
// The serialization code is auto-generated in `data.g.dart`.
import 'package:json_annotation/json_annotation.dart';
import 'package:timeago/timeago.dart' as timeago;

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
  final ({String version, Map<String, String> variant, String installedAt, String updatedAt})? installed;
  InstalledStatus(this.explicit, this.installed);
  factory InstalledStatus.fromJson(Map<String, dynamic> json) => _$InstalledStatusFromJson(json);

  String? timeLabel() {
    if (installed != null) {
      final prefix = installed!.installedAt == installed!.updatedAt ? 'installed' : 'updated';
      return "$prefix ${timeago.format(DateTime.parse(installed!.updatedAt))}";
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
