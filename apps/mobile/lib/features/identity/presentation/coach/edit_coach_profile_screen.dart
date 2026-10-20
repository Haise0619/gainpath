import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/coach_profile_cubit.dart';
import '../../application/coach_account_gateway.dart';
import 'coach_unsaved_changes_guard.dart';
import 'coach_account_session_guard.dart';
import 'coach_photo_crop.dart';
import 'certifications_screen.dart';

class EditCoachProfileScreen extends StatefulWidget {
  const EditCoachProfileScreen(
      {super.key, required this.controller, required this.accountRepository});
  final CoachProfileCubit controller;
  final CoachAccountGateway accountRepository;
  @override
  State<EditCoachProfileScreen> createState() => _EditCoachProfileScreenState();
}

class _EditCoachProfileScreenState extends State<EditCoachProfileScreen> {
  final name = TextEditingController(),
      specialty = TextEditingController(),
      bio = TextEditingController(),
      tags = TextEditingController(),
      years = TextEditingController(),
      fee = TextEditingController();
  static const suggestions = [
    'Strength Training',
    'Powerlifting',
    'Hypertrophy',
    'Mobility',
    'Injury Recovery',
    'Nutrition Coaching',
    'Beginner Friendly',
    'Calisthenics',
    'Weight Loss',
    'Sports Performance'
  ];
  List<String> get selectedTags => tags.text
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toList();
  void changeTags(List<String> values) =>
      setState(() => tags.text = values.join(', '));
  String? photoPath;
  AccountPhoto? photo;
  bool photoBusy = false;
  String? validation;
  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    final fields = widget.controller.state.profile?.fields;
    name.text = fields?.displayName ?? '';
    specialty.text = fields?.specialty ?? '';
    bio.text = fields?.bio ?? '';
    tags.text = fields?.specializationTags.join(', ') ?? '';
    years.text = fields?.yearsExperience?.toString() ?? '';
    fee.text = fields?.consultationFeeMinor == null
        ? ''
        : (fields!.consultationFeeMinor! / 100).toStringAsFixed(2);
    photoPath = fields?.photoPath;
    photo = null;
    validation = null;
  }

  @override
  void dispose() {
    for (final c in [name, specialty, bio, tags, years, fee]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final raw = years.text.trim(),
          parsed = raw.isEmpty ? null : int.tryParse(raw);
      if (raw.isNotEmpty && parsed == null) throw const FormatException();
      final rawFee = fee.text.trim();
      if (rawFee.isNotEmpty &&
          !RegExp(r'^\d{1,5}(\.\d{1,2})?$').hasMatch(rawFee)) {
        throw const FormatException(
            'Enter a fee with up to two decimal places.');
      }
      final feeMinor =
          rawFee.isEmpty ? null : (double.parse(rawFee) * 100).round();
      if (feeMinor != null && feeMinor > 1000000) {
        throw const FormatException('Fee must be MYR 10,000 or less.');
      }
      if (photo != null) {
        setState(() => photoBusy = true);
        photoPath = await widget.accountRepository.upload('coachProfilePhotos',
            newCoachRequestId(), photo!.bytes, photo!.contentType);
        if (!mounted) return;
        photo = null;
        if (mounted) setState(() => photoBusy = false);
      }
      final fields = CoachProfessionalFields(
          displayName: name.text,
          specialty: specialty.text,
          bio: bio.text,
          specializationTags: tags.text
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList(),
          yearsExperience: parsed,
          consultationFeeMinor: feeMinor,
          photoPath: photoPath);
      setState(() => validation = null);
      final priorRevision = widget.controller.state.profile?.revision ?? 0;
      await widget.controller.save(fields);
      if (mounted &&
          (widget.controller.state.profile?.revision ?? 0) > priorRevision) {
        setState(_reset);
      }
    } on FormatException {
      if (mounted) {
        setState(() => validation =
            'Check name, specialty, bio, tags, experience and fee (MYR 0–10,000, up to two decimals).');
      }
    } catch (_) {
      if (mounted) {
        setState(() => validation = 'Could not upload the photo. Try again.');
      }
    } finally {
      if (mounted) setState(() => photoBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<CoachProfileCubit,
          CoachProfileState>(
      bloc: widget.controller,
      builder: (context, state) {
        final enabled = state.status == CoachProfileStatus.ready &&
            !state.saving &&
            !state.conflict &&
            !photoBusy;
        final fields = state.profile?.fields;
        final dirty = photo != null ||
            photoPath != fields?.photoPath ||
            name.text != (fields?.displayName ?? '') ||
            specialty.text != (fields?.specialty ?? '') ||
            bio.text != (fields?.bio ?? '') ||
            tags.text != (fields?.specializationTags.join(', ') ?? '') ||
            years.text != (fields?.yearsExperience?.toString() ?? '') ||
            fee.text !=
                (fields?.consultationFeeMinor == null
                    ? ''
                    : (fields!.consultationFeeMinor! / 100).toStringAsFixed(2));
        return CoachUnsavedChangesGuard(
            dirty: dirty,
            busy: state.saving || photoBusy,
            isCurrent: widget.accountRepository.isCurrent,
            child: Scaffold(
                appBar: AppBar(title: const Text('Edit profile')),
                body: PageBody(children: [
                  const Text(
                      'Save a draft for Admin publication. Experience is self-reported.'),
                  const SizedBox(height: 16),
                  const Eyebrow('Professional identity'),
                  Panel(
                      child: Column(children: [
                    for (final entry in [
                      (name, 'Display name', 80),
                      (specialty, 'Specialty', 80),
                      (years, 'Years experience (optional)', 2)
                    ])
                      TextField(
                          controller: entry.$1,
                          enabled: enabled,
                          maxLength: entry.$3,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(labelText: entry.$2)),
                  ])),
                  const SizedBox(height: 20),
                  const Eyebrow('Bio'),
                  TextField(
                      controller: bio,
                      enabled: enabled,
                      maxLines: 6,
                      maxLength: 1000,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          labelText: 'Bio',
                          hintText:
                              'Tell members about your coaching approach')),
                  const SizedBox(height: 10),
                  const Eyebrow('Specialties'),
                  if (selectedTags.isEmpty)
                    const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child:
                            Text('Add at least one so members can find you.')),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final tag in selectedTags)
                      Chip(
                          label: Text(tag),
                          backgroundColor: AppColors.primaryTint,
                          labelStyle: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5),
                          deleteIconColor: AppColors.primary,
                          onDeleted: enabled
                              ? () => changeTags(selectedTags
                                  .where((value) => value != tag)
                                  .toList())
                              : null)
                  ]),
                  TextField(
                      controller: tags,
                      enabled: enabled,
                      maxLength: 334,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          labelText: 'Specialization tags (comma separated)',
                          helperText:
                              'Up to 8 specialties, 40 characters each.')),
                  const SizedBox(height: 14),
                  Text('Suggestions',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final tag in suggestions
                        .where((value) => !selectedTags.contains(value)))
                      ActionChip(
                          avatar: const Icon(Icons.add_rounded,
                              size: 16, color: AppColors.inkSoft),
                          label: Text(tag),
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(color: AppColors.hairline),
                          labelStyle: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600),
                          onPressed: enabled && selectedTags.length < 8
                              ? () => changeTags([...selectedTags, tag])
                              : null)
                  ]),
                  const SizedBox(height: 20),
                  const Eyebrow('Consultation fee'),
                  TextField(
                      controller: fee,
                      enabled: enabled,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          labelText: 'Consultation fee (MYR, optional)',
                          prefixText: 'RM ',
                          suffixText: 'per consultation',
                          helperText:
                              'Leave blank if no fee is set. Up to MYR 10,000.')),
                  const SizedBox(height: 20),
                  const Eyebrow('Branch'),
                  Panel(
                      background: AppColors.surfaceAlt,
                      child: Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 18, color: AppColors.inkSoft),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                widget.accountRepository.metrics.branch ??
                                    '-')),
                        const Text('Set by gym staff')
                      ])),
                  const SizedBox(height: 20),
                  const Eyebrow('Profile photo'),
                  Panel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        if (photo != null)
                          SizedBox(
                              width: 96,
                              height: 96,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Image.memory(photo!.bytes,
                                      fit: BoxFit.cover))),
                        OutlinedButton.icon(
                            onPressed: enabled
                                ? () async {
                                    try {
                                      final selected = await pickCoachPhoto(
                                          context, widget.accountRepository);
                                      widget.accountRepository.check();
                                      if (selected != null && mounted) {
                                        setState(() => photo = selected);
                                      }
                                    } catch (_) {
                                      if (mounted) {
                                        setState(() => validation =
                                            'Photo could not be opened. Check permission or choose another image.');
                                      }
                                    }
                                  }
                                : null,
                            icon: const Icon(Icons.photo_camera),
                            label: Text(photo != null
                                ? 'Change selected photo'
                                : photoPath != null
                                    ? 'Replace profile photo'
                                    : 'Add profile photo')),
                        if (photoPath != null || photo != null)
                          TextButton(
                              onPressed: enabled
                                  ? () => setState(() {
                                        photo = null;
                                        photoPath = null;
                                      })
                                  : null,
                              child: const Text('Remove profile photo')),
                        TextButton(
                            onPressed: enabled
                                ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            CoachAccountSessionGuard(
                                                repository:
                                                    widget.accountRepository,
                                                child: CertificationsScreen(
                                                    repository: widget
                                                        .accountRepository))))
                                : null,
                            child: const Text('Manage private certifications')),
                      ])),
                  const SizedBox(height: 24),
                  if (validation != null) Text(validation!),
                  if (state.message != null) Text(state.message!),
                  FilledButton(
                      onPressed: enabled ? _save : null,
                      child: Text(state.saving ? 'Saving…' : 'Save profile')),
                  TextButton(
                      onPressed: state.saving
                          ? null
                          : () async {
                              await widget.controller.reload();
                              if (mounted &&
                                  widget.controller.state.status ==
                                      CoachProfileStatus.ready) {
                                setState(_reset);
                              }
                            },
                      child: const Text('Discard and reload')),
                ])));
      });
}
