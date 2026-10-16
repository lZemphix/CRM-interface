import 'dart:async';

import 'package:flutter/material.dart';

import '../keyboard/command_scope.dart';
import '../keyboard/dialog_keyboard_scope.dart';
import '../keyboard/keybindings_dialog.dart';
import 'app_palette.dart';
import 'theme_settings.dart';

Future<void> showAppearanceSettings(BuildContext context) async {
  final controller = ThemeSettingsScope.maybeOf(context);
  if (controller == null) {
    if (KeybindingsScope.maybeOf(context) != null) {
      await showKeybindingsSettings(context);
    }
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => AppearanceSettings(controller: controller),
  );
}

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({super.key, required this.controller});
  final ThemeController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => DialogKeyboardScope(
      busy: false,
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Настройки',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Внешний вид приложения',
                            style: TextStyle(
                              color: context.colors.textMutted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('close-appearance-settings'),
                      tooltip: 'Закрыть настройки',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Цветовая тема',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                RadioGroup<ThemeMode>(
                  groupValue: controller.mode,
                  onChanged: (mode) {
                    if (mode != null && !controller.saving) {
                      unawaited(controller.setMode(mode));
                    }
                  },
                  child: Row(
                    children: [
                      for (final mode in [ThemeMode.light, ThemeMode.dark]) ...[
                        if (mode == ThemeMode.dark) const SizedBox(width: 14),
                        Expanded(
                          child: _ThemeOption(
                            mode: mode,
                            selected: controller.mode == mode,
                            enabled: !controller.saving,
                            onSelect: () => unawaited(controller.setMode(mode)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  controller.warning ??
                      (controller.saving
                          ? 'Сохраняем выбор…'
                          : 'Применяется сразу, без перезапуска. Выбор сохраняется на этом устройстве.'),
                  key: const Key('theme-settings-status'),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: controller.warning == null
                        ? context.colors.textMutted
                        : context.colors.warning,
                  ),
                ),
                if (KeybindingsScope.maybeOf(context) != null) ...[
                  const SizedBox(height: 22),
                  const Divider(),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => showKeybindingsSettings(context),
                    icon: const Icon(Icons.keyboard_outlined),
                    label: const Text('Горячие клавиши'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });
  final ThemeMode mode;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelect;
  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
      side: BorderSide(
        color: selected ? context.colors.accent : context.colors.strongBorder,
        width: selected ? 2 : 1,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey('theme-option-${mode.name}'),
      canRequestFocus: false,
      excludeFromSemantics: true,
      onTap: enabled ? onSelect : null,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ThemePreview(
              palette: mode == ThemeMode.dark
                  ? AppPalette.dark
                  : AppPalette.light,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Radio<ThemeMode>(
                  value: mode,
                  enabled: enabled,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Flexible(
                  child: Text(
                    mode == ThemeMode.dark ? 'Тёмная' : 'Светлая',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.palette});
  final AppPalette palette;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        height: 100,
        child: Row(
          children: [
            Container(
              width: 20,
              color: palette.sidebarBackground,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
              child: Column(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Container(
                      height: 9,
                      decoration: BoxDecoration(
                        color: i == 0
                            ? palette.activeElement
                            : const Color(0xFF344054),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 7),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: palette.background,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 68,
                        height: 6,
                        decoration: BoxDecoration(
                          color: palette.textMutted,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (var i = 0; i < 2; i++) ...[
                            if (i == 1) const SizedBox(width: 6),
                            Expanded(
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: palette.surface,
                                  border: Border.all(
                                    color: palette.notActiveBorder,
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      height: 4,
                                      color: palette.strongBorder,
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        width: 25,
                                        height: 4,
                                        color: palette.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
