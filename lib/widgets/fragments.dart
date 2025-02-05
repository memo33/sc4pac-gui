// This file contains small reusable widgets that are used in multiple places of the app.
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/link.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:badges/badges.dart' as badges;
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_markdown/flutter_markdown.dart' as fmd;
import 'package:open_file/open_file.dart';
import '../model.dart';
import '../viewmodel.dart' show PendingUpdateStatus;
import 'packagepage.dart';
import '../main.dart' show NavigationService;
import '../data.dart' show ChannelStats, InstalledStatus;

class ApiErrorWidget extends StatelessWidget {
  final ApiError error;
  const ApiErrorWidget(this.error, {super.key});
  @override
  Widget build(BuildContext context) {
    // TODO these widgets must be used with care as ListTile requires width constraints, so better replace with something more flexible
    if (error.detail.isNotEmpty) {
      return ExpansionTile(
        leading: const Icon(Icons.error_outline),
        title: Text(error.title),
        children: [Text(error.detail)],
      );
    } else {
      return ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(error.title),
      );
    }
  }

  static void dialog(Object error) {
    showDialog(
      context: NavigationService.navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error),
        content: ApiErrorWidget(ApiError.from(error)),
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

class PkgNameFragment extends StatelessWidget {
  final BareModule module;
  final bool asButton;
  final InstalledStatus? status;
  final bool colored;
  final String? localVariant;
  final void Function()? refreshParent;  // required if asButton
  final String? prefix, suffix;
  final bool asInlineButton;
  const PkgNameFragment(this.module, {super.key, this.asButton = false, this.asInlineButton = false, this.status, this.colored = true, this.localVariant, this.refreshParent, this.prefix, this.suffix});

  static const EdgeInsets padding = EdgeInsets.all(10);

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style; //.apply(fontFamily: GoogleFonts.notoSansMono().fontFamily);
    final style1 = colored ? style : style.copyWith(color: Theme.of(context).hintColor);
    final style2 = colored ? style.copyWith(color: Theme.of(context).primaryColor) : style;
    final text = RichText(
      text: TextSpan(
        style: style,
        children: [
          if (prefix?.isNotEmpty == true) TextSpan(text: prefix),
          TextSpan(text: '${module.group} : ', style: style1),
          TextSpan(text: module.name, style: style2),
          if (localVariant != null) TextSpan(text: ' : $localVariant', style: style1),
          if (suffix?.isNotEmpty == true) TextSpan(text: suffix),
        ],
      ),
    );
    return asButton
        ? TextButton.icon(
          onPressed: () => PackagePage.pushPkg(context, module, refreshPreviousPage: refreshParent ?? () {}),
          label: text,
          icon: status == null ? null : InstalledStatusIcon(status),
          iconAlignment: IconAlignment.start,
          style: TextButton.styleFrom(padding: PkgNameFragment.padding),
        )
        : asInlineButton
        ? InkWell(
          onTap: () => PackagePage.pushPkg(context, module, refreshPreviousPage: refreshParent ?? () {}),
          child: text,
        )
        : text;
  }
}

class CopyButton extends StatelessWidget {
  final String copyableText;
  final Widget child;
  const CopyButton({required this.copyableText, required this.child, super.key});
  @override Widget build(BuildContext context) {
    return Wrap(
      direction: Axis.horizontal,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      children: [
        child,
        IconButton(
          tooltip: "Copy to clipboard",
          icon: const Icon(Icons.copy),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: copyableText));
          },
        ),
      ]
    );
  }
}

class Hyperlink extends StatelessWidget {
  final Uri? url;
  Hyperlink({required String url, super.key}) : url = Uri.tryParse(url);
  @override Widget build(BuildContext context) {
    return RichText(
      text: WidgetSpan(
        child: Link(
          uri: url,
          builder: (context, followLink) => InkWell(
            // opens new tab in web (in contrast to `followLink`) and external browser on other platforms
            onTap: url == null ? null : () => launchUrl(url!, mode: LaunchMode.externalApplication),
            child: Text(url.toString(), style: DefaultTextStyle.of(context).style.copyWith(color: Theme.of(context).primaryColor)),
          ),
        ),
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
  final void Function()? refreshParent;
  PkgLinkElementBuilder({required this.refreshParent});

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
          refreshParent: refreshParent,
        ),
      ));
    } else {
      return null;
    }
  }
}

class MarkdownText extends StatelessWidget {
  final String text;
  final void Function()? refreshParent;
  const MarkdownText(this.text, {this.refreshParent, super.key});

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
      builders: {PkgLinkNode.pkgNodeTag: PkgLinkElementBuilder(refreshParent: refreshParent)},
      softLineBreak: false,
      styleSheet: fmd.MarkdownStyleSheet(
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
  PackageTileChip.variant(String label, String value, {Key? key, String? description}) :
      this(label: Text('$label: $value'), key: key, description: description);
  // const PackageTileChip.explicit({Key? key, void Function()? onDeleted}) :
  //     this(label: const Text('explicitly installed'), key: key, onDeleted: onDeleted, filled: true);

  @override
  Widget build(BuildContext context) {
    final chip = Chip(
      avatar: description == null ? null : const Icon(Icons.info_outlined),
      label: label,
      onDeleted: onDeleted,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
      // materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
      // labelPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
      // shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
      backgroundColor: !filled ? null : Theme.of(context).colorScheme.secondaryContainer,
      side: !filled ? null : BorderSide.none,
    );
    return description == null ? chip : Tooltip(message: description, child: chip);
  }
}

class InstalledStatusIcon extends StatelessWidget {
  final InstalledStatus? status;
  const InstalledStatusIcon(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    String tooltip = "Not installed";
    Widget? icon;
    if (status != null) {
      if (status!.explicit) {
        if (status!.installed == null) {
          tooltip = "Update pending";
          icon = Icon(Symbols.deployed_code_history, color: Theme.of(context).colorScheme.secondary);
        } else {
          tooltip = "Installed explicitly";
          icon = InstalledStatusIconExplicit(color: Theme.of(context).colorScheme.secondary);
        }
      } else if (status!.installed != null) {
        tooltip = "Installed as dependency";
        icon = InstalledStatusIconDependency(color: Theme.of(context).colorScheme.secondary);
      } // else not explicit and not installed
    }
    return Tooltip(message: tooltip, child: icon ?? const Icon(Icons.token_outlined));
  }
}
class InstalledStatusIconExplicit extends StatelessWidget {
  final Color? color;
  final Color? badgeColor;
  final double badgeScale;
  const InstalledStatusIconExplicit({this.color, this.badgeColor, this.badgeScale = 1.0, super.key});
  @override Widget build(BuildContext context) {
    return badges.Badge(
      badgeContent: Icon(Icons.star, size: 13 * badgeScale, color: color),
      position: badges.BadgePosition.bottomEnd(bottom: -3 * badgeScale, end: -2 * badgeScale),
      badgeAnimation: const badges.BadgeAnimation.scale(toAnimate: false),
      badgeStyle: badges.BadgeStyle(
        padding: EdgeInsets.all(1.2 * badgeScale),
        badgeColor: badgeColor ?? Theme.of(context).colorScheme.surface,
      ),
      child: Icon(Symbols.deployed_code, color: color),
    );
  }
}
class InstalledStatusIconDependency extends StatelessWidget {
  final Color? color;
  const InstalledStatusIconDependency({this.color, super.key});
  @override Widget build(BuildContext context) {
    return Icon(Symbols.package_2, color: color);
  }
}

class StarIconButton extends StatefulWidget {
  final bool initialCheckedValue;
  final void Function(bool) onToggled;
  const StarIconButton(this.initialCheckedValue, {required this.onToggled, super.key});
  @override State<StarIconButton> createState() => _StarIconButtonState();
}
class _StarIconButtonState extends State<StarIconButton> {
  late bool _checked = widget.initialCheckedValue;
  @override Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Symbols.star, fill: _checked ? 1 : 0),
      color: _checked ? Theme.of(context).colorScheme.secondary : null,
      tooltip: _checked ? "Remove from explicit Plugins" : "Add to Plugins explicitly",
      onPressed: () {
        setState(() {
          _checked = !_checked;
          widget.onToggled(_checked);  // finishes quickly, i.e. not awaiting async computation
        });
      }
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
  final void Function(bool)? onToggled;
  final void Function() refreshParent;
  final VisualDensity? visualDensity;
  const PackageTile(this.module, this.index, {super.key, this.summary, this.chips = const [], this.status, this.pendingStatus, this.debugChannelUrls, this.onToggled, required this.refreshParent, this.visualDensity});
  @override
  Widget build(BuildContext context) {
    final explicit = status?.explicit ?? false;
    final hintStyle = DefaultTextStyle.of(context).style.copyWith(color: Theme.of(context).hintColor);
    final timeLabel = status?.timeLabel();
    return ListTile(
      leading: pendingStatus != null ? PendingUpdateStatusIcon(pendingStatus!) : InstalledStatusIcon(status),
      title: Wrap(spacing: 10, children: [PkgNameFragment(module), ...chips]),
      subtitle: summary == null && status == null ? null : Row(
        children: [
          summary != null ? Expanded(child: MarkdownText(summary!, refreshParent: refreshParent)) : const Spacer(),
          if (status?.installed != null) const SizedBox(width: 10), // DividerIcon(),
          if (status?.installed != null) Tooltip(message: "Version", child: TextWithIcon(status!.installed!.version, symbol: Symbols.sell, style: hintStyle)),
          if (timeLabel != null) const SizedBox(width: 20), // DividerIcon(),
          if (timeLabel != null) TextWithIcon(timeLabel, symbol: Symbols.schedule, style: hintStyle),
        ],
      ),
      visualDensity: visualDensity,
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // passing a key is important to trigger redraw of button if index of list tile changes (e.g. due to filtering)
          if (onToggled != null) StarIconButton(explicit, onToggled: onToggled!, key: ValueKey((module, explicit))),
          Text((index+1).toString()),
        ],
      ),
      onTap: () => PackagePage.pushPkg(context, module, debugChannelUrls: debugChannelUrls, refreshPreviousPage: refreshParent),
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
      leadingIcon: Icon(symbols[selectedCategory] ?? Symbols.category_search),
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
          leadingIcon: Icon(symbols[c.category], color: Theme.of(context).hintColor),
          trailingIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(c.count?.toString() ?? '')),
        ),
      ).toList(),
    );
  }

  static final symbols = {
    '050-load-first': Symbols.event_upcoming,
    '100-props-textures': Symbols.grid_view,
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
    '900-overrides': Symbols.event_repeat,
  };
}

class PathField extends StatelessWidget {
  final String path;
  const PathField({required this.path, super.key});
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
        if (!kIsWeb)
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
