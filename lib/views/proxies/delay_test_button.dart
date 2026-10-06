import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The proxies page's delay test as a labelled button for the navigation
/// dock: the open tab's group, or every unfolded group of the list.
class ProxiesDelayTestButton extends ConsumerWidget {
  const ProxiesDelayTestButton({super.key});

  List<String> _targets(WidgetRef ref) {
    final isTab = ref.watch(
      proxiesStyleSettingProvider.select(
        (state) => state.type == ProxiesType.tab,
      ),
    );
    if (isTab) {
      final current = ref.watch(
        proxiesTabControllerStateProvider.select(
          (state) => state.currentGroupName,
        ),
      );
      return [?current];
    }
    final state = ref.watch(proxiesListStateProvider);
    return [
      for (final group in state.groups)
        if (state.currentUnfoldSet.contains(group.name)) group.name,
    ];
  }

  Future<void> _test(WidgetRef ref, List<String> targets) async {
    final action = ref.read(proxiesActionProvider.notifier);
    await Future.wait(targets.map(action.delayTestPageGroup));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = _targets(ref);
    final isTesting = ref.watch(
      delayTestingGroupsProvider.select(
        (testing) => targets.any(testing.contains),
      ),
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final height = NavigationDock.heightOf(context);
    return Theme(
      data: theme.copyWith(
        floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
          extendedSizeConstraints: BoxConstraints.tightFor(height: height),
        ),
      ),
      child: FloatingActionButton.extended(
        heroTag: null,
        onPressed: isTesting || targets.isEmpty
            ? null
            : () => _test(ref, targets),
        icon: isTesting
            ? DotMarch(
                color: colorScheme.onPrimaryContainer,
                unlitColor: colorScheme.onPrimaryContainer.opacity38,
              )
            : const GlyphIcon(AppGlyphs.bolt, fill: 1),
        label: Text(context.appLocalizations.delayTest),
      ),
    );
  }
}
