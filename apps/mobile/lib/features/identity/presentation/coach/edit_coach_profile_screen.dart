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
    final rawFeeInput = fee.text.trim();
    var cleanedFee = rawFeeInput;
    if (cleanedFee.toLowerCase().startsWith('rm')) {
      cleanedFee = cleanedFee.substring(2).trim();
    } else if (cleanedFee.toLowerCase().startsWith('myr')) {
      cleanedFee = cleanedFee.substring(3).trim();
    }

    try {
      final raw = years.text.trim(),
          parsed = raw.isEmpty ? null : int.tryParse(raw);
      if (raw.isNotEmpty && parsed == null) {
        throw const FormatException('Years of experience must be a whole number.');
      }
      if (cleanedFee.isNotEmpty &&
          !RegExp(r'^\d{1,5}(\.\d{1,2})?$').hasMatch(cleanedFee)) {
        throw const FormatException(
            'Enter a valid fee (e.g. 150.00) with up to two decimal places.');
      }
      final feeMinor =
          cleanedFee.isEmpty ? null : (double.parse(cleanedFee) * 100).round();
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

      final currentFields = widget.controller.state.profile?.fields;
      final patch = CoachProfilePatch.between(currentFields, fields);
      if (patch.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No changes to save.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final priorRevision = widget.controller.state.profile?.revision ?? 0;
      await widget.controller.save(fields);
      if (mounted) {
        final currentRevision = widget.controller.state.profile?.revision ?? 0;
        if (currentRevision > priorRevision) {
          setState(_reset);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile draft saved. Pending Admin publication.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        } else if (widget.controller.state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.controller.state.message!),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } on FormatException catch (e) {
      if (mounted) {
        final msg = e.message.isNotEmpty
            ? e.message
            : 'Check name, specialty, bio, tags, experience and fee (MYR 0–10,000, up to two decimals).';
        setState(() => validation = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        const msg = 'Could not save the profile. Check connection and try again.';
        setState(() => validation = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.danger,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => photoBusy = false);
    }
  }

  Widget? _saveBar(bool enabled, bool dirty, CoachProfileState state) {
    final show = dirty || state.saving || photoBusy || state.conflict;
    if (!show) return null;

    final saving = state.saving || photoBusy;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.hairline)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  saving
                      ? Icons.sync_rounded
                      : state.conflict
                          ? Icons.warning_amber_rounded
                          : Icons.edit_note_rounded,
                  size: 16,
                  color: state.conflict
                      ? AppColors.warning
                      : (saving ? AppColors.inkSoft : AppColors.primary),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    saving
                        ? 'Saving profile draft…'
                        : state.conflict
                            ? 'Profile changed elsewhere'
                            : 'Unsaved profile changes',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: state.conflict
                          ? AppColors.warning
                          : (saving ? AppColors.inkSoft : AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            await widget.controller.reload();
                            if (mounted &&
                                widget.controller.state.status ==
                                    CoachProfileStatus.ready) {
                              setState(_reset);
                            }
                          },
                    child: const Text('Discard and reload',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: enabled ? _save : null,
                    child: saving
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text('Saving…',
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          )
                        : const Text('Save profile',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
        final currentFeeMinor = () {
          final rawFee = fee.text.trim();
          if (rawFee.isEmpty) return null;
          final d = double.tryParse(rawFee);
          return d == null ? -1 : (d * 100).round();
        }();
        final dirty = photo != null ||
            photoPath != fields?.photoPath ||
            name.text != (fields?.displayName ?? '') ||
            specialty.text != (fields?.specialty ?? '') ||
            bio.text != (fields?.bio ?? '') ||
            tags.text != (fields?.specializationTags.join(', ') ?? '') ||
            years.text != (fields?.yearsExperience?.toString() ?? '') ||
            currentFeeMinor != fields?.consultationFeeMinor;
        return CoachUnsavedChangesGuard(
            dirty: dirty,
            busy: state.saving || photoBusy,
            isCurrent: widget.accountRepository.isCurrent,
            child: Scaffold(
                appBar: AppBar(title: const Text('Edit profile')),
                bottomNavigationBar: _saveBar(enabled, dirty, state),
                body: PageBody(children: [
                  // Notice Header Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 18, color: AppColors.primary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Save a draft for Admin publication. Experience and credentials are self-reported.',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.inkSoft,
                                height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Professional Identity
                  const Eyebrow('Professional identity'),
                  Panel(
                    child: Column(
                      children: [
                        TextField(
                          controller: name,
                          enabled: enabled,
                          maxLength: 80,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Display name',
                          ),
                        ),
                        TextField(
                          controller: specialty,
                          enabled: enabled,
                          maxLength: 80,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Specialty',
                          ),
                        ),
                        TextField(
                          controller: years,
                          enabled: enabled,
                          maxLength: 2,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Years experience (optional)',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Bio
                  const Eyebrow('Bio'),
                  TextField(
                    controller: bio,
                    enabled: enabled,
                    maxLines: 4,
                    maxLength: 1000,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      alignLabelWithHint: true,
                      hintText:
                          'Tell members about your coaching approach, experience, and background',
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Specialties
                  const Eyebrow('Specialties'),
                  if (selectedTags.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Add at least one so members can find you.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.inkSoft),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in selectedTags)
                        Chip(
                          label: Text(tag),
                          backgroundColor: AppColors.primaryTint,
                          labelStyle: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                          deleteIconColor: AppColors.primary,
                          onDeleted: enabled
                              ? () => changeTags(selectedTags
                                  .where((value) => value != tag)
                                  .toList())
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tags,
                    enabled: enabled,
                    maxLength: 334,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Specialization tags (comma separated)',
                      helperText:
                          'Up to 8 specialties, 40 characters each.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Suggestions',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in suggestions
                          .where((value) => !selectedTags.contains(value)))
                        ActionChip(
                          avatar: const Icon(Icons.add_rounded,
                              size: 16, color: AppColors.inkSoft),
                          label: Text(tag),
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(
                              color: AppColors.hairline),
                          labelStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                          onPressed: enabled && selectedTags.length < 8
                              ? () => changeTags([...selectedTags, tag])
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Consultation fee
                  const Eyebrow('Consultation fee'),
                  TextField(
                    controller: fee,
                    enabled: enabled,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Consultation fee (MYR, optional)',
                      prefixText: 'RM ',
                      suffixText: 'per consultation',
                      helperText:
                          'Leave blank if no fee is set. Up to MYR 10,000.',
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Branch
                  const Eyebrow('Branch'),
                  Panel(
                    background: AppColors.surfaceAlt,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 18, color: AppColors.inkSoft),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.accountRepository.metrics.branch ?? '-',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.hairline,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Assigned by gym',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.inkSoft),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Profile Photo
                  const Eyebrow('Profile photo'),
                  Panel(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar Preview
                        Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: photo != null
                                        ? AppColors.primary
                                        : AppColors.hairline,
                                    width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0C000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: photo != null
                                    ? Image.memory(photo!.bytes,
                                        fit: BoxFit.cover)
                                    : (photoPath != null
                                        ? const Center(
                                            child: Icon(Icons.person_rounded,
                                                size: 44,
                                                color: AppColors.primary))
                                        : const Center(
                                            child: Icon(
                                                Icons.person_outline_rounded,
                                                size: 40,
                                                color: AppColors.inkSoft))),
                              ),
                            ),
                            if (photo != null)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_rounded,
                                      size: 12, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        // Photo Actions
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: enabled
                                    ? () async {
                                        try {
                                          final selected = await pickCoachPhoto(
                                              context,
                                              widget.accountRepository);
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
                                icon: const Icon(Icons.photo_camera_rounded,
                                    size: 16),
                                label: Text(
                                  photo != null
                                      ? 'Change selected photo'
                                      : photoPath != null
                                          ? 'Replace profile photo'
                                          : 'Add profile photo',
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                              if (photoPath != null || photo != null) ...[
                                const SizedBox(height: 2),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: enabled
                                      ? () => setState(() {
                                            photo = null;
                                            photoPath = null;
                                          })
                                      : null,
                                  child: const Text('Remove profile photo',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ],
                              const SizedBox(height: 2),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: enabled
                                    ? () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                CoachAccountSessionGuard(
                                                    repository: widget
                                                        .accountRepository,
                                                    child: CertificationsScreen(
                                                        repository: widget
                                                            .accountRepository))))
                                    : null,
                                child: const Text(
                                  'Manage private certifications',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (validation != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(validation!,
                          style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600)),
                    ),
                  if (state.message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(state.message!,
                          style: TextStyle(
                              color: state.status ==
                                          CoachProfileStatus.error ||
                                      state.conflict
                                  ? AppColors.danger
                                  : AppColors.success,
                              fontWeight: FontWeight.w600)),
                    ),
                ])));
      });
}
