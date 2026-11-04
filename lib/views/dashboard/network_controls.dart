import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/proxies/card.dart' show selectGroupProxy;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'layout.dart';
import 'network_panel.dart';
import 'widgets/connection_stats.dart';
import 'widgets/profiles.dart';
import 'widgets/proxy_groups.dart' show showProxiesSheet;

bool _switchable(Group group) =>
    group.type == GroupType.Selector || group.type.isComputedSelected;

class NetworkProxySwitch extends ConsumerWidget {
  const NetworkProxySwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref
        .watch(currentGroupsStateProvider)
        .value
        .where(_switchable);
    final preferred = ref.watch(
      currentProfileProvider.select((profile) => profile?.currentGroupName),
    );
    final group =
        groups.where((group) => group.name == preferred).firstOrNull ??
        groups.firstOrNull;
    if (group == null) return const SizedBox.shrink();
    return NetworkPanel(child: _ProxyShortcut(group: group));
  }
}

class NetworkDashboardControls extends StatelessWidget {
  const NetworkDashboardControls({super.key, required this.platform});

  final SupportPlatform platform;

  @override
  Widget build(BuildContext context) => DashboardDensityScope(
    density: DashboardDensity.mobile,
    scale: MediaQuery.textScalerOf(context).scale(1),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 3
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Text(
              context.appLocalizations.quickControls,
              style: AppTextStyle.headline.of(context),
            ),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(width: width, child: const ProfilesCard()),
                SizedBox(
                  width: width,
                  child: _RoutingControls(platform: platform),
                ),
                SizedBox(width: width, child: const _ProxyShortcuts()),
              ],
            ),
            const ConnectionStatsCard(),
          ],
        );
      },
    ),
  );
}

class _RoutingControls extends ConsumerWidget {
  const _RoutingControls({required this.platform});

  final SupportPlatform platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = context.appLocalizations;
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final desktop = platform != SupportPlatform.Android;
    return NetworkPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(
            labels.outboundMode,
            style: AppTextStyle.subheadline.of(context, emphasized: true),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final candidate in Mode.values)
                OutlinedButton(
                  onPressed: candidate == mode
                      ? null
                      : () => ref
                            .read(setupActionProvider.notifier)
                            .changeMode(candidate),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      if (candidate == mode)
                        const GlyphIcon(AppGlyphs.check, size: 14),
                      Text(candidate.label),
                    ],
                  ),
                ),
            ],
          ),
          if (desktop) ...[
            _ControlSwitch(
              label: labels.systemProxy,
              value: ref.watch(
                networkSettingProvider.select((state) => state.systemProxy),
              ),
              onChanged: (value) => ref
                  .read(networkSettingProvider.notifier)
                  .update((state) => state.copyWith(systemProxy: value)),
            ),
            _ControlSwitch(
              label: 'TUN',
              value: ref.watch(
                patchClashConfigProvider.select((state) => state.tun.enable),
              ),
              onChanged: (value) => ref
                  .read(patchClashConfigProvider.notifier)
                  .update((state) => state.copyWith.tun(enable: value)),
            ),
          ] else
            _ControlSwitch(
              label: 'VPN',
              value: ref.watch(
                vpnSettingProvider.select((state) => state.enable),
              ),
              onChanged: (value) => ref
                  .read(vpnSettingProvider.notifier)
                  .update((state) => state.copyWith(enable: value)),
            ),
        ],
      ),
    );
  }
}

class _ControlSwitch extends StatelessWidget {
  const _ControlSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 12,
    children: [
      Expanded(child: Text(label, style: AppTextStyle.subheadline.of(context))),
      Semantics(
        label: label,
        child: Switch(value: value, onChanged: onChanged),
      ),
    ],
  );
}

class _ProxyShortcuts extends ConsumerWidget {
  const _ProxyShortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = context.appLocalizations;
    final groups = ref.watch(currentGroupsStateProvider).value;
    final selectable = groups.where(_switchable).take(4).toList();
    return NetworkPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  labels.quickSwitchProxy,
                  style: AppTextStyle.subheadline.of(context, emphasized: true),
                ),
              ),
              IconButton(
                tooltip: labels.proxyGroup,
                onPressed: () => showProxiesSheet(context),
                icon: const GlyphIcon(AppGlyphs.proxies, size: 18),
              ),
            ],
          ),
          if (selectable.isEmpty)
            Text(
              labels.nullTip(labels.proxyGroup),
              style: AppTextStyle.caption1.of(context),
            )
          else
            for (final group in selectable) _ProxyShortcut(group: group),
        ],
      ),
    );
  }
}

class _ProxyShortcut extends ConsumerWidget {
  const _ProxyShortcut({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedProxyNameProvider(group.name));
    final connected = ref.watch(coreStatusProvider) == CoreStatus.connected;
    final labels = context.appLocalizations;
    void step(int delta) {
      final current = group.all.indexWhere((proxy) => proxy.name == selected);
      final index = ((current < 0 ? 0 : current) + delta) % group.all.length;
      selectGroupProxy(
        ref,
        groupName: group.name,
        groupType: group.type,
        proxyName: group.all[index].name,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        Text(
          group.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.caption1
              .of(context)
              .copyWith(color: context.colorScheme.onSurfaceVariant),
        ),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () =>
                    showProxiesSheet(context, groupName: group.name),
                child: EmojiText(
                  selected ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              tooltip: labels.previousProxy,
              onPressed: connected && group.all.length > 1
                  ? () => step(-1)
                  : null,
              icon: const GlyphIcon(AppGlyphs.chevronBack, size: 16),
            ),
            IconButton(
              tooltip: labels.nextProxy,
              onPressed: connected && group.all.length > 1
                  ? () => step(1)
                  : null,
              icon: const GlyphIcon(AppGlyphs.chevronForward, size: 16),
            ),
          ],
        ),
      ],
    );
  }
}
