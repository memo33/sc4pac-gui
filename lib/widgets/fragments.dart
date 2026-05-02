// This file contains small reusable widgets that are used in multiple places of the app.
import 'dart:math' show Random;
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:url_launcher/link.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:badges/badges.dart' as badges;
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_markdown/flutter_markdown.dart' as fmd;
import 'package:open_file/open_file.dart';
import '../icomoon_icons.dart' show Icomoon;
import '../model.dart';
import '../viewmodel.dart' show PendingUpdateStatus, PendingUpdates, World;
import 'packagepage.dart';
import '../main.dart' show NavigationService;
import '../data.dart' show ChannelStats, InstalledStatus;

const listViewTextPadding = EdgeInsets.symmetric(vertical: 10, horizontal: 5);

class ApiErrorWidget extends StatelessWidget {
  final ApiError error;
  const ApiErrorWidget(this.error, {super.key});
  static Widget scroll(ApiError error, {Key? key}) => SingleChildScrollView(child: ApiErrorWidget(error, key: key));
  static const padding = EdgeInsets.symmetric(vertical: 10, horizontal: 20);
  @override
  Widget build(BuildContext context) {
    // TODO these widgets must be used with care as ListTile requires width constraints, so better replace with something more flexible
    return ExpansionTile(
      leading: const Icon(Icons.error_outline),
      title: Text(error.title),
      children: [
        if (error.detail.isNotEmpty)
          Padding(padding: padding, child: Text(error.detail)),
        DebugInfoCard(createDebugInfo(error).join("\n")),
      ],
    );
  }

  static List<String> createDebugInfo(ApiError? error) {
    final String? javaVersion = switch (World.world.serverStatus) {
      null => null,
      final s => "${s['javaVersion']} - ${s['javaRuntime']}",
    };
    return [
      "Sc4pac GUI version: ${World.world.appInfo.version}",
      "Sc4pac CLI version: ${World.world.serverVersion}",
      "Platform: ${defaultTargetPlatform.name}",
      "Web: $kIsWeb",
      "Java: $javaVersion",
      "OS (Java): ${World.world.serverStatus?['osVersion']}",
      ...kIsWeb ? [] : [
        "OS (Dart): ${io.Platform.operatingSystem} - ${io.Platform.operatingSystemVersion}",
        "Dart: ${io.Platform.version}",
        "Exe: ${io.Platform.resolvedExecutable}",
        "Arguments: ${World.world.args.arguments}",
      ],
      "",
      if (error != null) ...[
        "Error type: ${error.type}",
        "Error title: ${error.title}",
        "Error detail: ${error.detail}",
        "",
      ],
      "Init phase: ${World.world.initPhase}",
      "Authority: ${World.world.authority}",
      "Authenticated: ${World.world.settings == null ? null : World.world.settings?.stAuth != null}",
      "Profiles config folder: ${World.world.profiles?.profilesDir}",
      "Profile ID: ${World.world.profileInitialized ? World.world.profile.id : null}",
      "Profile name: ${World.world.profileInitialized ? World.world.profile.name : null}",
      "Plugins folder: ${World.world.profileInitialized ? World.world.profile.paths?.plugins : null}",
      "Cache folder: ${World.world.profileInitialized ? World.world.profile.paths?.cache : null}",
      "",
      "Server log:${World.world.server?.stderrBuffer.isNotEmpty == true ? "" : " null"}",
      ...?World.world.server?.stderrBuffer,
    ];
  }

  static Future<void> dialog(Object error) {
    return showDialog(
      context: NavigationService.navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error),
        content: ApiErrorWidget.scroll(ApiError.from(error)),
        actions: [
          OutlinedButton(
            child: const Text("Dismiss"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class DebugInfoCard extends StatelessWidget {
  final String debugInfo;
  const DebugInfoCard(this.debugInfo, {super.key});
  @override
  Widget build(BuildContext context) {
    final hintStyle = TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25));
    return Card(
      child: Padding(
        padding: ApiErrorWidget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Tooltip(
                  message: "Include this data if you report the problem. It helps identify the source of the issue.",
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Symbols.bug_report, color: hintStyle.color),
                      const SizedBox(width: 8),
                      Text("Debug Info", style: hintStyle),
                      const SizedBox(width: 24),
                      Icon(Symbols.info, color: hintStyle.color, size: 18),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Spacer(),
                AnimatedCopyButton(
                  label: const Text("Copy"),
                  getCopyableText: () => "```\n${debugInfo.trim()}\n```",
                ),
              ],
            ),
            Divider(color: Theme.of(context).scaffoldBackgroundColor),
            Text(debugInfo, style: hintStyle),
          ],
        ),
      ),
    );
  }
}

class PkgNameFragment extends StatelessWidget {
  final BareModule module;
  final bool asButton;
  final InstalledStatus? status;
  final bool colored;
  final String? localVariant;
  final String? prefix, suffix;
  final bool asInlineButton;
  const PkgNameFragment(this.module, {super.key, this.asButton = false, this.asInlineButton = false, this.status, this.colored = true, this.localVariant, this.prefix, this.suffix});

  static const EdgeInsets padding = EdgeInsets.all(10);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = DefaultTextStyle.of(context).style; //.apply(fontFamily: GoogleFonts.notoSansMono().fontFamily);
    final style1 = colored ? style.copyWith(color: theme.primaryColorLight) : style.copyWith(color: theme.hintColor);
    final style2 = colored ? style.copyWith(color: theme.primaryColor) : style;
    final text = RichText(
      text: TextSpan(
        style: style,
        children: [
          if (prefix?.isNotEmpty == true) TextSpan(text: prefix),
          TextSpan(text: '${module.group} : ', style: style1),
          TextSpan(text: module.name, style: style2),
          if (localVariant != null) TextSpan(text: ' : $localVariant', style: style),
          if (suffix?.isNotEmpty == true) TextSpan(text: suffix),
        ],
      ),
    );
    return asButton
        ? TextButton.icon(
          onPressed: () => PackagePage.pushPkg(context, module),
          label: text,
          icon: status == null ? null : InstalledStatusIcon(status, module: module, listen: false),  // TODO listen here instead
          iconAlignment: IconAlignment.start,
          style: TextButton.styleFrom(padding: PkgNameFragment.padding),
        )
        : asInlineButton
        ? InkWell(
          onTap: () => PackagePage.pushPkg(context, module),
          child: text,
        )
        : text;
  }
}

class TextWithCopyButton extends StatelessWidget {
  final String copyableText;
  final Widget child;
  const TextWithCopyButton({required this.copyableText, required this.child, super.key});
  @override Widget build(BuildContext context) {
    return Wrap(
      direction: Axis.horizontal,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      children: [
        child,
        AnimatedCopyButton(
          getCopyableText: () => copyableText,
        ),
      ]
    );
  }
}

class AnimatedActionButton extends StatefulWidget {
  final Widget Function(BuildContext context, Widget icon, VoidCallback? onPressed) builder;
  final IconData symbol;
  final VoidCallback? action;
  const AnimatedActionButton({required this.builder, required this.symbol, required this.action, super.key});
  @override State<AnimatedActionButton> createState() => _AnimatedActionButtonState();
}
class _AnimatedActionButtonState extends State<AnimatedActionButton> {
  int _count = 0;
  bool _recentlyPressed = false;

  @override
  Widget build(BuildContext context) {
    final onPressed = switch (widget.action) {  // `onPressed` must be defined inside `build`, as null-ness depends on context
      null => null,
      final f => () async {
        _count++;
        final startedAtCount = _count;
        _recentlyPressed = true;
        setState(() {});
        f();  // not waiting for potential asynchronous computation which could take a long time
        await Future.delayed(const Duration(milliseconds: 2500), () {
          if (_count == startedAtCount && mounted) {
            setState(() => _recentlyPressed = false);
          }
        });
      }
    };
    final animatedIcon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Icon(
        _recentlyPressed ? Icons.check : widget.symbol,
        key: ValueKey<bool>(_recentlyPressed),
        color: _recentlyPressed ? Theme.of(context).colorScheme.secondary : null,
      ),
    );
    return widget.builder(context, animatedIcon, onPressed);
  }
}

class AnimatedCopyButton extends StatelessWidget {
  final Widget? label;
  final String Function()? getCopyableText;
  const AnimatedCopyButton({this.label, this.getCopyableText, super.key});
  @override Widget build(BuildContext context) {
    return Tooltip(
      message: "Copy to clipboard",
      child: AnimatedActionButton(
        builder: (context, icon, onPressed) => switch (label) {
          null => IconButton(icon: icon, onPressed: onPressed),
          final label => TextButton.icon(icon: icon, label: label, onPressed: onPressed),
        },
        symbol: Icons.copy,
        action: switch (getCopyableText) {
          null => null,
          final f => () => Clipboard.setData(ClipboardData(text: f())),
        },
      ),
    );
  }
}

class Hyperlink extends StatelessWidget {
  final String urlStr;
  final String? text;
  const Hyperlink({required String url, this.text, super.key}) : urlStr = url;
  static String urlTooltip(String url) => switch (url.indexOf('?')) { final i => i < 0 ? url : "${url.substring(0, i)}?..." };
  @override Widget build(BuildContext context) {
    final url = Uri.tryParse(urlStr);
    final link = Link(
      uri: url,
      builder: (context, followLink) => CopyLinkAddress(
        url: urlStr,
        child: InkWell(
          onTap: url == null ? null : () {
            ContextMenuController.removeAny();
            // opens new tab in web (in contrast to `followLink`) and external browser on other platforms
            launchUrl(url, mode: LaunchMode.externalApplication);
          },
          child: Text(text ?? urlStr, style: DefaultTextStyle.of(context).style.copyWith(color: const Color(0xff2196f3))),  // steel blue
        ),
      ),
    );
    return RichText(
      text: WidgetSpan(
        child: text == null ? link : Tooltip(message: urlTooltip(urlStr), child: link),
      ),
    );
  }
}

// NOTE: Remember to use `ContextMenuController.removeAny()` in the child button press handler.
class CopyLinkAddress extends StatelessWidget {
  final String url;
  final Widget child;
  const CopyLinkAddress({required this.url, required this.child, super.key});
  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: child,
      contextMenuBuilder: (context, editableTextState) => AdaptiveTextSelectionToolbar.buttonItems(
        anchors: editableTextState.contextMenuAnchors,
        buttonItems: [
          ContextMenuButtonItem(
            label: "Copy link address",
            onPressed: () async {
              ContextMenuController.removeAny();
              await Clipboard.setData(ClipboardData(text: url.toString()));
            },
          ),
        ],
      ),
    );
  }
}

class PkgLinkNode extends md.Element {
  final BareModule module;
  final String prefix, suffix;
  static const pkgNodeTag = 'sc4pacPkg';
  PkgLinkNode(this.module, {required this.prefix, required this.suffix}) : super.withTag(pkgNodeTag);
}

class PkgLinkSyntax extends md.InlineSyntax {
  PkgLinkSyntax() : super(pkgMarkdownPattern);

  // regex also matches leading and trailing non-whitespace text (e.g. parenthesis) to ensure it does not get wrapped
  static const pkgMarkdownPattern = r'([^`\s]*)`pkg=([^`:\s]+):([^`:\s]+)`([^`\s]*)';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(PkgLinkNode(BareModule(match[2]!, match[3]!), prefix: match[1]!, suffix: match[4]!));
    return true;  // i.e. advance parser by match[0].length
  }
}

class PkgLinkElementBuilder extends fmd.MarkdownElementBuilder {
  PkgLinkElementBuilder();

  @override
  Widget? visitElementAfterWithContext(BuildContext context, md.Element element, TextStyle? preferredStyle, TextStyle? parentStyle) {
    if (element is PkgLinkNode) {
      return Text.rich(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: PkgNameFragment(
          element.module,
          prefix: element.prefix,
          suffix: element.suffix,
          asInlineButton: true,
        ),
      ));
    } else {
      return null;
    }
  }
}

class MarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const MarkdownText(this.text, {this.style, super.key});

  static final _extensionSet = md.ExtensionSet(
    md.ExtensionSet.gitHubFlavored.blockSyntaxes,
    [
      PkgLinkSyntax(),
      ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes
    ],
  );

  @override
  Widget build(BuildContext context) {
    return fmd.MarkdownBody(
      data: text,
      extensionSet: _extensionSet,
      builders: {PkgLinkNode.pkgNodeTag: PkgLinkElementBuilder()},
      softLineBreak: false,
      styleSheet: fmd.MarkdownStyleSheet(
        p: style,
        blockquoteDecoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(4)),
        code: DefaultTextStyle.of(context).style.copyWith(color: Theme.of(context).colorScheme.tertiary),
      ),
      onTapLink: (text, href, title) {
        if (href != null) {
          final url = Uri.tryParse(href);
          if (url != null) {
            launchUrl(url, mode: LaunchMode.externalApplication);
          }
        }
      },
    );
  }
}

class PackageTileChip extends StatelessWidget {
  final Widget label;
  final void Function()? onDeleted;
  final bool filled;
  final String? description;
  const PackageTileChip({required this.label, super.key, this.onDeleted, this.filled = false, this.description});
  PackageTileChip.variant(String label, String value, BareModule module, {Key? key, String? description}) :
    this(
      label: Text('${stripVariantPackagePrefix(variantId: label, package: module.toString())} = $value'),
      key: key,
      description: description,
    );
  PackageTileChip.variantValue({required String value, Key? key, String? description, bool filled = false}) :
    this(
      label: Text(value),
      key: key,
      description: description,
      filled: filled,
    );

  static String stripVariantPackagePrefix({required String variantId, required String package}) {
    if (variantId.startsWith(package) && variantId.startsWith(':', package.length)) {
      return variantId.substring(package.length + 1);
    } else {
      return variantId;
    }
  }

  static const visualDensity = VisualDensity(horizontal: 0, vertical: -4);
  static const padding = EdgeInsets.symmetric(vertical: 0, horizontal: 0);

  @override
  Widget build(BuildContext context) {
    final chip = Chip(
      avatar: description?.isNotEmpty == true ? Icon(Symbols.info, color: Theme.of(context).colorScheme.onSurface) : null,
      label: label,
      onDeleted: onDeleted,
      visualDensity: visualDensity,
      // materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: padding,
      // labelPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
      // shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
      backgroundColor: !filled ? null : Theme.of(context).colorScheme.secondaryContainer,
      side: !filled ? null : BorderSide.none,
    );
    return description == null ? chip : Tooltip(message: description, child: chip);
  }
}

enum _InstalledStatusIconMessage {
  notInstalled, installedAsDependency, installedExplicitly, updatePending, reinstallPending, uninstallPending,
}
class InstalledStatusIcon extends StatelessWidget {
  final InstalledStatus? status;
  final BareModule module;
  final bool listen;
  const InstalledStatusIcon(this.status, {required BareModule this.module, required this.listen, super.key});

  static const List<String> _messages = [
    "Not installed", "Installed as dependency", "Installed explicitly", "Update pending", "Reinstall pending", "Uninstall pending",
  ];

  static _InstalledStatusIconMessage _categorize(InstalledStatus? status, {required bool isFlipped, required PendingUpdateStatus? pendingStatus}) {
    if (status == null) {
      if (isFlipped) {
        return _InstalledStatusIconMessage.updatePending;
      } else {  // not explicit and not installed
        return _InstalledStatusIconMessage.notInstalled;
      }
    } else {  // status != null
      if (pendingStatus == PendingUpdateStatus.remove) {
        return _InstalledStatusIconMessage.uninstallPending;
      } else if (/*status!.installed?.reinstall == true ||*/ pendingStatus == PendingUpdateStatus.reinstall) {  // status.installed.reinstall is commented out so that icon refreshes after Update All
        return _InstalledStatusIconMessage.reinstallPending;
      } else if (status!.explicit && !isFlipped || !(status!.explicit) && isFlipped) {
        if (status!.installed == null) {
          return _InstalledStatusIconMessage.updatePending;
        } else {
          return _InstalledStatusIconMessage.installedExplicitly;
        }
      } else if (status!.installed != null) {  // installed, but not explicit
        return _InstalledStatusIconMessage.installedAsDependency;
      } else {  // not explicit and not installed
        return _InstalledStatusIconMessage.notInstalled;
      }
    }
  }

  Widget _buildDefault(BuildContext context, {required bool isFlipped, required PendingUpdateStatus? pendingStatus}) {
    final _InstalledStatusIconMessage tooltip = _categorize(status, isFlipped: isFlipped, pendingStatus: pendingStatus);
    Widget icon = switch(tooltip) {
      _InstalledStatusIconMessage.notInstalled => const InstalledStatusIconOther(Icons.token_outlined, colored: false),
      _InstalledStatusIconMessage.installedAsDependency => const InstalledStatusIconDependency(colored: true),
      _InstalledStatusIconMessage.installedExplicitly => const InstalledStatusIconExplicit(colored: true),
      _InstalledStatusIconMessage.updatePending => const InstalledStatusIconOther(Symbols.deployed_code_history),
      _InstalledStatusIconMessage.uninstallPending => const InstalledStatusIconOther(Symbols.auto_delete),
      _InstalledStatusIconMessage.reinstallPending => const InstalledStatusIconOther(Symbols.settings_backup_restore),
    };
    return Tooltip(message: _messages[tooltip.index], child: icon);
  }

  @override
  Widget build(BuildContext context) {
    final child = _buildDefault(context, isFlipped: false, pendingStatus: null);
    if (!listen) {
      return child;
    } else {
      final pendingUpdates = World.world.profile.dashboard.pendingUpdates;
      final initialCheckedValue = status?.explicit ?? false;
      return ListenableBuilder(
        listenable: pendingUpdates,
        child: child,
        builder: (context, child) =>
          pendingUpdates.isToggleStateFlipped(module, checked: initialCheckedValue)
          ? _buildDefault(context, isFlipped: true, pendingStatus: pendingUpdates.getPendingStatus(module))
          : switch (pendingUpdates.getPendingStatus(module)) {
            null => child!,
            final pendingStatus => _buildDefault(context, isFlipped: false, pendingStatus: pendingStatus),
          },
      );
    }
  }
}

class InstalledStatusIconExplicit extends StatelessWidget {
  final bool colored;
  final Color? badgeColor;
  final double badgeScale;
  final Widget? child;
  final double fill;
  const InstalledStatusIconExplicit({required this.colored, this.badgeColor, this.badgeScale = 1.0, this.child, this.fill = 1.0, super.key});
  @override Widget build(BuildContext context) {
    final Color? color = colored ? Theme.of(context).colorScheme.secondary : null;
    return badges.Badge(
      badgeContent: Icon(Symbols.star, size: 13 * badgeScale, color: color, fill: fill),
      position: badges.BadgePosition.bottomEnd(bottom: -3 * badgeScale, end: -2 * badgeScale),
      badgeAnimation: const badges.BadgeAnimation.scale(toAnimate: false),
      badgeStyle: badges.BadgeStyle(
        padding: EdgeInsets.all(1.2 * badgeScale),
        badgeColor: badgeColor ?? Theme.of(context).colorScheme.surface,
      ),
      child: child ?? Icon(Symbols.deployed_code, color: color),
    );
  }
}
class InstalledStatusIconDependency extends StatelessWidget {
  final bool colored;
  const InstalledStatusIconDependency({required this.colored, super.key});
  @override Widget build(BuildContext context) {
    return Icon(Symbols.package_2, color: colored ? Theme.of(context).colorScheme.secondary : null);
  }
}
class InstalledStatusIconOther extends StatelessWidget {
  final bool colored;
  final IconData symbol;
  const InstalledStatusIconOther(this.symbol, {this.colored = true, super.key});
  @override Widget build(BuildContext context) {
    return Icon(symbol, color: colored ? Theme.of(context).colorScheme.secondary : null);
  }
}

class StarIconButton extends StatelessWidget {
  final bool initialCheckedValue;
  final void Function()? afterToggled;
  final BareModule module;
  final bool iconOnly;
  const StarIconButton(this.initialCheckedValue, {required this.afterToggled, required this.module, this.iconOnly = true, super.key});

  Widget _buildDefault(BuildContext context, PendingUpdates pendingUpdates, {required bool isFlipped}) {
    bool b = initialCheckedValue ^ isFlipped;
    final VoidCallback onPressed = () async {
      await pendingUpdates.onToggledStarButton(module, !b);
      if (afterToggled != null) {
        afterToggled!();
      }
    };
    final key = ValueKey((module, b));  // passing a key is important to avoid flicker on hover at rebuilds
    final icon = Icon(Symbols.star, fill: b ? 1 : 0);
    return iconOnly
      ? IconButton(
        key: key,
        icon: icon,
        color: b ? Theme.of(context).colorScheme.secondary : null,
        tooltip: b ? "Remove from explicit Plugins" : "Add to Plugins explicitly",
        onPressed: onPressed,
      )
      : FilledButton.icon(
        key: key,
        icon: icon,
        label: Text(b ? "Added to Plugins explicitly" : "Add to Plugins explicitly"),
        onPressed: onPressed,
      );
  }

  @override Widget build(BuildContext context) {
    final pendingUpdates = World.world.profile.dashboard.pendingUpdates;
    return ListenableBuilder(
      listenable: pendingUpdates,
      child: _buildDefault(context, pendingUpdates, isFlipped: false),  // may avoid rebuilds of buttons that have not been toggled since last update
      builder: (context, child) => pendingUpdates.isToggleStateFlipped(module, checked: initialCheckedValue)
        ? _buildDefault(context, pendingUpdates, isFlipped: true)
        : child!,
    );
  }
}

class PendingUpdateStatusIcon extends StatelessWidget {
  final PendingUpdateStatus status;
  const PendingUpdateStatusIcon(this.status, {super.key});
  @override Widget build(BuildContext context) {
    return Tooltip(
      message: switch (status) {
        PendingUpdateStatus.remove => "Package will be removed",
        PendingUpdateStatus.add => "New",
        PendingUpdateStatus.reinstall => "Update",
      },
      child: Icon(switch (status) {
        PendingUpdateStatus.remove => Icons.remove_circle_outline,
        PendingUpdateStatus.add => Icons.add_circle_outline,
        PendingUpdateStatus.reinstall => Icons.sync_outlined,
      }),
    );
  }
}

// class DividerIcon extends StatelessWidget {
//   const DividerIcon({super.key});
//   @override Widget build(BuildContext context) => Padding(
//     padding: const EdgeInsets.symmetric(horizontal: 5),
//     child: Icon(Symbols.stat_0, size: 10, fill: 1, color: Theme.of(context).dividerColor),
//   );
// }

class TextWithIcon extends StatelessWidget {
  final String version;
  final TextStyle? style;
  final IconData symbol;
  const TextWithIcon(this.version, {this.style, super.key, required this.symbol});
  @override Widget build(BuildContext context) {
    final style = this.style ?? DefaultTextStyle.of(context).style;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Icon(symbol, size: style.fontSize, color: style.color),
        Text(version, style: style),
      ],
    );
  }
}

class PackageTile extends StatelessWidget {
  final BareModule module;
  final String? summary;
  final int index;
  // final Widget? actionButton;
  final List<Widget> chips;
  final InstalledStatus? status;
  final PendingUpdateStatus? pendingStatus;
  final Set<String>? debugChannelUrls;
  final void Function()? afterToggled;
  final VisualDensity? visualDensity;
  final bool selected;
  final void Function()? onSelected;
  const PackageTile(this.module, this.index, {super.key, this.summary, this.chips = const [], this.status, this.pendingStatus, this.debugChannelUrls, this.afterToggled, this.visualDensity, this.selected = false, this.onSelected});
  @override
  Widget build(BuildContext context) {
    final explicit = status?.explicit ?? false;
    final hintStyle = DefaultTextStyle.of(context).style.copyWith(color: Theme.of(context).hintColor);
    final timeLabel = status?.timeLabel();
    final tags = [
      if (status?.installed != null) Tooltip(message: "Version", child: TextWithIcon(status!.installed!.version, symbol: Symbols.sell, style: hintStyle)),
      if (timeLabel != null) TextWithIcon(timeLabel, symbol: Symbols.schedule, style: hintStyle),
    ];
    final tagsWidget = tags.isEmpty ? null : Wrap(
      direction: Axis.horizontal,
      alignment: WrapAlignment.end,
      spacing: 20,
      children: tags,
    );
    return ListTile(
      leading: pendingStatus != null ? PendingUpdateStatusIcon(pendingStatus!) : InstalledStatusIcon(status, module: module, listen: true),
      title: Wrap(spacing: 10, children: [PkgNameFragment(module), ...chips]),
      subtitle: summary?.isEmpty == true && tagsWidget == null ? null : LayoutBuilder(builder: (context, constraints) {
        final summaryWidget = summary != null ? MarkdownText(summary!) : null;
        if (constraints.maxWidth < 400) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (summaryWidget != null) Align(alignment: Alignment.topLeft, child: summaryWidget),
              if (tagsWidget != null) tagsWidget,
            ],
          );
        } else {
          return Row(
            children: [
              if (summaryWidget != null) Expanded(child: summaryWidget),
              if (summaryWidget != null && tagsWidget != null) const SizedBox(width: 10),
              if (tagsWidget != null)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth - 200),
                  child: tagsWidget,
                ),
            ],
          );
        }
      }),
      visualDensity: visualDensity,
      // selected: selected,  // commented out to avoid colored icon
      tileColor: selected ? Theme.of(context).focusColor.withOpacity(0.12) : null,  // instead of selectedTileColor
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (afterToggled != null) StarIconButton(explicit, afterToggled: afterToggled!, module: module),
          Text((index+1).toString()),
        ],
      ),
      onTap: () {
        if (onSelected != null) {
          onSelected!();
        }
        PackagePage.pushPkg(context, module, debugChannelUrls: debugChannelUrls);
      },
    );
  }
}

class CenteredFullscreenDialog extends StatelessWidget {
  final Widget? title;
  final Widget child;
  const CenteredFullscreenDialog({this.title, required this.child, super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null ? null : AppBar(centerTitle: true, title: title),
      body: Center(  // vertically centered
        child: SingleChildScrollView(  // both Center widgets are needed so that scrollbars appear on the very outside
          child: Center(  // horizontally centered
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class PackageSearchBar extends StatefulWidget {
  final String? initialText;
  final String hintText;
  final void Function(String) onSubmitted;
  final void Function() onCanceled;
  final Future<int> resultsCount;
  const PackageSearchBar({required this.initialText, this.hintText = "search term…", required this.onSubmitted, required this.onCanceled, required this.resultsCount, super.key});
  @override State<PackageSearchBar> createState() => _PackageSearchBarState();
}
class _PackageSearchBarState extends State<PackageSearchBar> {
  late final controller = TextEditingController(text: widget.initialText);
  late final focusNode = FocusNode();

  @override
  dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SearchBar(
    controller: controller,
    focusNode: focusNode,
    hintText: widget.hintText,
    padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
    leading: const Icon(Symbols.search),
    // or onChanged for immediate feedback?
    onSubmitted: widget.onSubmitted,
    trailing: [
      FutureBuilder<int>(
        future: widget.resultsCount,
        builder: (context, snapshot) => Row(children: [
          Text((!snapshot.hasError && snapshot.hasData) ? '${snapshot.data!} packages' : ''),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: "Cancel search",
              icon: const Icon(Symbols.cancel, fill: 1),
              onPressed: () {
                setState(() {
                  controller.text = '';
                  focusNode.requestFocus();
                });
                widget.onCanceled();
              },
            ),
        ]),
      )
    ],
  );
}

class CategoryMenu extends StatefulWidget {
  static const double width = 260;
  final ChannelStats? stats;
  final ValueChanged<String?>? onSelected;
  final String? initialCategory;
  final double? menuHeight;
  const CategoryMenu({required this.stats, this.onSelected, this.initialCategory, this.menuHeight, super.key});
  @override State<CategoryMenu> createState() => _CategoryMenuState();
}
class _CategoryMenuState extends State<CategoryMenu> {
  late String? selectedCategory = widget.initialCategory;
  late final TextEditingController _controller = TextEditingController(text: selectedCategory);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allCategories = [
      (category: null, count: widget.stats?.totalPackageCount),  // All
      ...? widget.stats?.categories,
    ];
    return DropdownMenu<String?>(
      controller: _controller,
      menuHeight: widget.menuHeight,
      width: CategoryMenu.width,
      onSelected: (s) {
        setState(() { selectedCategory = s; });
        if (widget.onSelected != null) {
          widget.onSelected!(s);
        }
      },
      leadingIcon: CategoryIcon(selectedCategory, fallback: Symbols.category_search),
      initialSelection: selectedCategory,
      label: const Text('Category'),
      // enableFilter: true,
      // inputDecorationTheme: const InputDecorationTheme(
      //   contentPadding: EdgeInsets.symmetric(vertical: 5.0),
      // ),
      menuStyle: const MenuStyle(
        visualDensity: VisualDensity(horizontal: 0, vertical: -4),
      ),
      dropdownMenuEntries: allCategories.map((c) =>
        DropdownMenuEntry<String?>(
          value: c.category,
          label: c.category ?? "All",
          leadingIcon: CategoryIcon(c.category, color: Theme.of(context).hintColor),
          trailingIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(c.count?.toString() ?? '')),
        ),
      ).toList(),
    );
  }
}

class CategoryIcon extends StatelessWidget {
  final String? category;
  final Color? color;
  final IconData? fallback;
  const CategoryIcon(this.category, {this.fallback, this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(_symbols[category] ?? fallback, color: color);
  }

  static final _symbols = {
    '050-load-first': Symbols.event_upcoming,
    '060-config': Symbols.settings_applications,
    '100-props-textures': Symbols.grid_view,
    '110-resources': Symbols.schema,  // or Symbols.pallet
    '140-ordinances': Symbols.rule,
    '150-mods': Symbols.tune,  // or Symbols.build
    '170-terrain': Symbols.landscape,
    '180-flora': Symbols.forest,
    '200-residential': Symbols.house,
    '300-commercial': Symbols.shopping_cart,
    '360-landmark': Symbols.things_to_do,
    '400-industrial': Symbols.factory,
    '410-agriculture': Symbols.agriculture,
    '500-utilities': Symbols.bolt,
    '600-civics': Symbols.account_balance,
    '610-safety': Symbols.fire_hydrant,
    '620-education': Symbols.school,
    '630-health': Symbols.emergency,
    '640-government': Symbols.gavel,
    '650-religion': [Symbols.church, Symbols.mosque, Symbols.synagogue][Random().nextInt(3)],
    '660-parks': Symbols.nature_people,
    '700-transit': Symbols.commute,
    '710-automata': Symbols.traffic_jam,
    '770-network-addon-mod': Icomoon.namLogo2021BlackPad10,
    '900-overrides': Symbols.event_repeat,
  };
}

class PathField extends StatelessWidget {
  final String path;
  final bool isPlugins;
  const PathField({required this.path, this.isPlugins = false, super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: TextFormField(
              decoration: const InputDecoration(
                labelText: 'Path'
              ),
              readOnly: true,
              initialValue: path,
            ),
          ),
        ),
        if (isPlugins) const OpenPluginsFolderButton(iconOnly: true, symbol: Symbols.open_in_new_down),  // works in web as well
        if (!isPlugins && !kIsWeb)  // TODO deduplicate with OpenPluginsFolderButton
          Tooltip(message: 'Open in file browser', child: IconButton(
            icon: const Icon(Symbols.open_in_new_down),
            onPressed: () async {
              OpenResult result = await OpenFile.open(path);  // does not work in web
              if (result.type != ResultType.done) {
                debugPrint("${result.type}: ${result.message}");
              }
            },
          )),
      ],
    );
  }
}

class OutlinedDisplayBlock extends StatelessWidget {
  static const double inset = 20;
  final Widget child;
  const OutlinedDisplayBlock({required this.child, super.key});
  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: inset, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor.withAlpha(0x1c), width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class DisplayBlock extends StatelessWidget {
  final double elevation;
  final Widget child;
  const DisplayBlock({required this.child, this.elevation = 2, super.key});
  @override Widget build(BuildContext context) {
    return Card.filled(
      elevation: elevation,
      surfaceTintColor: Theme.of(context).colorScheme.primary,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
        child: child,
      ),
    );
  }
}

class OpenFolderIcon extends StatelessWidget {
  final Color? color;
  const OpenFolderIcon({this.color, super.key});
  @override Widget build(BuildContext context) {
    return badges.Badge(
      badgeContent: RotatedBox(quarterTurns: 1, child: Icon(Symbols.arrow_outward, size: 12, color: color, weight: 600)),
      position: badges.BadgePosition.bottomEnd(bottom: -3, end: -3),
      badgeAnimation: const badges.BadgeAnimation.scale(toAnimate: false),
      badgeStyle: badges.BadgeStyle(
        padding: const EdgeInsets.all(1),
        badgeColor: Theme.of(context).colorScheme.surface,
      ),
      child: Icon(Symbols.folder_open, color: color),
    );
  }
}

class OpenPluginsFolderButton extends StatelessWidget {
  final BareModule? module;
  final bool iconOnly;
  final IconData? symbol;
  final Color? color;
  const OpenPluginsFolderButton({required this.iconOnly, this.module, this.symbol, this.color, super.key});
  Future<void> _onPressed() => World.world.openPluginsFolder(module: module).catchError(ApiErrorWidget.dialog);
  @override Widget build(BuildContext context) {
    final icon = symbol != null ? Icon(symbol, color: color) : OpenFolderIcon(color: color);
    if (iconOnly) {
      return Tooltip(
        message: 'Open Plugins folder',
        child: IconButton(icon: icon, onPressed: _onPressed),
      );
    } else {
      return TextButton.icon(
        icon: icon,
        label: const Text("Open Plugins folder"),
        onPressed: _onPressed,
      );
    }
  }
}

class LabeledCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;
  final Color? color;
  const LabeledCheckbox({required this.label, required this.value, required this.onChanged, this.color, super.key});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Checkbox(
            value: value,
            onChanged: onChanged,
            side: color != null ? BorderSide(color: color!, width: 2) : null,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: Text(label, style: color != null ? TextStyle(color: color) : null),
          ),
        ],
      ),
    );
  }
}
