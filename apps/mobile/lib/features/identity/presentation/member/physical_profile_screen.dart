import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show FitnessProfile, ProfileGender;
import 'package:gainpath_identity/gainpath_identity.dart'
    show FitnessProfileCubit;
import 'save_live_profile.dart';

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
  late double _age = widget.liveProfile?.age.toDouble() ??
      context.read<MemberProfileRepository>().memberAge.toDouble();
  late double _height = widget.liveProfile?.heightCm.toDouble() ??
      context.read<MemberProfileRepository>().memberHeight.toDouble();
  late double _weight = widget.liveProfile?.weightKg.toDouble() ??
      context.read<MemberProfileRepository>().memberWeight.toDouble();

  static const _genders = ['Female', 'Male', 'Prefer not to say'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Physical profile')),
      body: PageBody(
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              selected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          g == 'Prefer not to say' ? 'Other' : g,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : AppColors.inkSoft,
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
            onPressed: () async {
              if (widget.liveCubit != null) {
                await saveLiveProfile(
                    context,
                    widget.liveCubit!,
                    widget.liveProfile!.copyWith(
                      gender: ProfileGender.values
                          .firstWhere((value) => value.label == _gender),
                      age: _age.round(),
                      heightCm: _height.round(),
                      weightKg: _weight.round(),
                    ));
                return;
              }
              Navigator.pop(context);
              showToast(context, 'Physical profile updated.');
            },
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}
