import 'package:flutter/material.dart';

import 'sound_effects.dart';

class SoundEffectsSetting extends StatefulWidget {
  const SoundEffectsSetting({super.key});

  @override
  State<SoundEffectsSetting> createState() => _SoundEffectsSettingState();
}

class _SoundEffectsSettingState extends State<SoundEffectsSetting> {
  bool? _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await SoundEffects.enabled();
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _change(bool value) async {
    setState(() => _saving = true);
    final saved = await SoundEffects.setEnabled(value);
    if (!mounted) return;
    setState(() {
      if (saved) _enabled = value;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) => _enabled == null
      ? const SizedBox.shrink()
      : SwitchListTile(
          secondary: const Icon(Icons.volume_up_outlined),
          title: const Text('Sound effects'),
          subtitle:
              const Text('Sounds for workouts, check-ins and arcade games'),
          value: _enabled!,
          onChanged: _saving ? null : _change,
        );
}
