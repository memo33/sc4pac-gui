// This file contains small reusable widgets that are used in multiple places of the app.
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/link.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '../model.dart';
import 'packagepage.dart';
import '../main.dart' show NavigationService;
import '../data.dart' show ChannelStats;

class ApiErrorWidget extends StatelessWidget {
  final ApiError error;
  const ApiErrorWidget(this.error, {super.key});
  @override
  Widget build(BuildContext context) {
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
  final bool isInstalled;
  final bool colored;
  // final Widget? leading;
  const PkgNameFragment(this.module, {super.key, this.asButton = false, this.isInstalled = false, this.colored = true/*, this.leading*/});

  static const EdgeInsets padding = EdgeInsets.all(10);

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style; //.apply(fontFamily: GoogleFonts.notoSansMono().fontFamily);
    final text = RichText(
      text: TextSpan(
        style: style,
        children: [
          // if (leading != null) WidgetSpan(child: leading!),
          // if (leading != null) const WidgetSpan(child: SizedBox(width: 10)),
          TextSpan(
            text: '${module.group} : ',
            style: colored ? style : style.copyWith(color: Theme.of(context).hintColor),
          ),
          TextSpan(
            text: module.name,
            style: colored ? style.copyWith(color: Theme.of(context).primaryColor) : style/*.copyWith(fontWeight: FontWeight.bold)*/,
          ),
        ],
      ),
    );
    return !asButton ? text : TextButton.icon(
      onPressed: () => PackagePage.pushPkg(context, module),
      label: text,
      icon: !isInstalled ? null : const Tooltip(message: 'Installed', child: Icon(Icons.download_done)),  // TODO installed or added/marked for installation?
      iconAlignment: IconAlignment.start,
      style: TextButton.styleFrom(padding: PkgNameFragment.padding),
    );
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

class MarkdownText extends StatelessWidget {
  final String text;
  const MarkdownText(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: text.trimRight().split('\n').map((line) =>
        Text(line)
      ).toList(),
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
  const PackageTileChip.explicit({Key? key, void Function()? onDeleted}) :
      this(label: const Text('explicitly installed'), key: key, onDeleted: onDeleted, filled: true);

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

class PackageTile extends StatelessWidget {
  final BareModule module;
  final String? subtitle;
  final int index;
  final Widget? actionButton;
  final List<Widget> chips;
  const PackageTile(this.module, this.index, {super.key, this.subtitle, this.actionButton, this.chips = const []});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.token_outlined),
      title: Wrap(spacing: 10, children: [PkgNameFragment(module), ...chips]),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: actionButton ?? Text('${index+1}'),
      onTap: () => PackagePage.pushPkg(context, module),
    );
  }
}

class CategoryMenu extends StatefulWidget {
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
      width: 400,
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
