import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show FitnessProfile, ProfileGender, AgeBracket;
import 'package:gainpath_identity/gainpath_identity.dart'
    show FitnessProfileCubit;
import 'save_live_profile.dart';
import 'module1_edit_guard.dart';

class PhysicalProfileScreen extends StatefulWidget {
  const PhysicalProfileScreen({super.key, this.liveProfile, this.liveCubit});
  final FitnessProfile? liveProfile;
  final FitnessProfileCubit? liveCubit;

  @override
  State<PhysicalProfileScreen> createState() => _PhysicalProfileScreenState();
}

class _PhysicalProfileScreenState extends State<PhysicalProfileScreen> {
  late String _gender = widget.liveProfile?.gender.label ??
      context.read<MemberProfileRepository>().memberGender;
  late double _age = widget.liveProfile?.age?.toDouble() ??
      (widget.liveProfile == null
          ? context.read<MemberProfileRepository>().memberAge!.toDouble()
          : 25);
  late AgeBracket? _ageBracket = widget.liveProfile?.effectiveAgeBracket;
  bool _ageBracketEdited = false, _saving = false;
  late double _height = widget.liveProfile?.heightCm.toDouble() ??
      context.read<MemberProfileRepository>().memberHeight.toDouble();
  late double _weight = widget.liveProfile?.weightKg.toDouble() ??
      context.read<MemberProfileRepository>().memberWeight.toDouble();

  static const _genders = ['Female', 'Male', 'Prefer not to say'];
  bool get _dirty => widget.liveProfile != null
      ? (_gender != widget.liveProfile!.gender.label ||
          _height.round() != widget.liveProfile!.heightCm ||
          _weight.round() != widget.liveProfile!.weightKg ||
          _ageBracketEdited && (_ageBracket != widget.liveProfile!.ageBracket))
      : _gender != context.read<MemberProfileRepository>().memberGender ||
          _height.round() !=
              context.read<MemberProfileRepository>().memberHeight ||
          _weight.round() !=
              context.read<MemberProfileRepository>().memberWeight ||
          _age.round() != context.read<MemberProfileRepository>().memberAge;

  @override
  Widget build(BuildContext context) {
    return Module1EditGuard(
        dirty: _dirty,
        busy: _saving,
        child: Scaffold(
          appBar: AppBar(title: const Text('Physical profile')),
          body: AbsorbPointer(
              absorbing: _saving,
              child: PageBody(
                children: [
                  const Eyebrow('Gender'),
                  Panel(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: _genders.map((g) {
                        final selected = g == _gender;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(11),
                              onTap: () => setState(() => _gender = g),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Text(
                                  g,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.inkSoft,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (widget.liveProfile != null) ...[
                    const Eyebrow('Age bracket'),
                    DropdownButtonFormField<AgeBracket>(
                        initialValue: _ageBracket,
                        decoration: const InputDecoration(
                            labelText: 'Age bracket',
                            helperText: 'No birthdate is required.'),
                        items: AgeBracket.values
                            .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text('${value.label} years')))
                            .toList(),
                        onChanged: (value) => setState(() {
                              _ageBracket = value;
                              _ageBracketEdited = true;
                            })),
                    if (widget.liveProfile!.age != null)
                      Text(
                          'Previously saved age: ${widget.liveProfile!.age}. Selecting a bracket replaces that exact age.'),
                  ] else ...[
                    const Eyebrow('Age'),
                    NumberDial(
                      value: _age,
                      min: 13,
                      max: 80,
                      suffix: '',
                      display: '${_age.round()}',
                      captionUnit: 'years old',
                      onChanged: (v) => setState(() => _age = v),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Eyebrow('Height'),
                  NumberDial(
                    value: _height,
                    min: 130,
                    max: 210,
                    suffix: ' cm',
                    display: '${_height.round()}',
                    captionUnit: 'centimetres',
                    onChanged: (v) => setState(() => _height = v),
                  ),
                  const SizedBox(height: 18),
                  const Eyebrow('Weight'),
                  NumberDial(
                    value: _weight,
                    min: 35,
                    max: 160,
                    suffix: ' kg',
                    display: '${_weight.round()}',
                    captionUnit: 'kilograms',
                    onChanged: (v) => setState(() => _weight = v),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            if (widget.liveCubit != null) {
                              setState(() => _saving = true);
                              try {
                                await saveLiveProfile(
                                    context,
                                    widget.liveCubit!,
                                    widget.liveProfile!.copyWith(
                                      gender: ProfileGender.values.firstWhere(
                                          (value) => value.label == _gender),
                                      age: _ageBracketEdited
                                          ? null
                                          : widget.liveProfile!.age,
                                      ageBracket: _ageBracketEdited
                                          ? _ageBracket
                                          : widget.liveProfile!.ageBracket,
                                      heightCm: _height.round(),
                                      weightKg: _weight.round(),
                                    ));
                              } finally {
                                if (mounted) setState(() => _saving = false);
                              }
                              return;
                            }
                            Navigator.pop(context);
                            showToast(context, 'Physical profile updated.');
                          },
                    child: Text(_saving ? 'Saving…' : 'Save changes'),
                  ),
                ],
              )),
        ));
  }
}
