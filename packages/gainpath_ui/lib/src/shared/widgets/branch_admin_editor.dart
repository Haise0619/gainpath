part of 'branch_directory_page.dart';

/// Translates a branch save rejection without coupling this view to Firebase.
class BranchSaveException implements Exception {
  const BranchSaveException({required this.code});

  final String code;
}

class _AdminBranchEditor extends StatefulWidget {
  const _AdminBranchEditor({
    required this.branch,
    required this.request,
    required this.pickCover,
    required this.onSaved,
    required this.onCancel,
    required this.onLeaveCheckChanged,
  });

  final Map<String, dynamic>? branch;
  final BranchRequest request;
  final Future<String?> Function()? pickCover;
  final VoidCallback onSaved;
  final VoidCallback onCancel;
  final ValueChanged<Future<bool> Function()?> onLeaveCheckChanged;

  @override
  State<_AdminBranchEditor> createState() => _AdminBranchEditorState();
}

enum _BranchDayMode {
  hours('Open'),
  closed('Closed'),
  allDay('Open 24 hours');

  const _BranchDayMode(this.label);
  final String label;
}

class _BranchEditorDay {
  _BranchEditorDay(Object? value) {
    if (value is! Map) return;
    if (value['closed'] == true) {
      mode = _BranchDayMode.closed;
    } else if (value['allDay'] == true) {
      mode = _BranchDayMode.allDay;
    } else if (value['open'] is String && value['close'] is String) {
      mode = _BranchDayMode.hours;
      opens.text = value['open'] as String;
      closes.text = value['close'] as String;
    }
  }

  _BranchDayMode? mode;
  final opens = TextEditingController();
  final closes = TextEditingController();

  List<String?> get draft => [mode?.name, opens.text, closes.text];

  void dispose() {
    opens.dispose();
    closes.dispose();
  }
}

class _AdminBranchEditorState extends State<_AdminBranchEditor> {
  static const _labels = {
    'branchId': 'Branch ID',
    'displayName': 'Branch name',
    'description': 'Description',
    'address': 'Full address',
    'city': 'City',
    'state': 'State',
    'postalCode': 'Postal code',
    'country': 'Country',
    'contactPhone': 'Phone',
    'contactEmail': 'Email',
    'latitude': 'Latitude',
    'longitude': 'Longitude',
    'facilities': 'Facilities',
  };
  static const _addressFields = ['city', 'state', 'postalCode', 'country'];
  static const _optionalTextFields = [
    'description',
    'address',
    ..._addressFields,
    'contactPhone',
    'contactEmail',
  ];
  static const _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static final _idShape = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final _timeShape = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
  static const _coverLimit = 2 * 1024 * 1024;

  final _form = GlobalKey<FormState>();
  late final _values = {
    for (final key in _labels.keys)
      key: TextEditingController(
        text: key == 'facilities'
            ? (widget.branch?[key] as List?)?.join(', ')
            : widget.branch?[key]?.toString(),
      ),
  };
  List? get _savedHours => widget.branch?['openingHours'] as List?;
  bool get _hasSavedHours => _savedHours?.length == 7;
  late final _hours = List.generate(7,
      (index) => _BranchEditorDay(_hasSavedHours ? _savedHours![index] : null));
  late bool _editHours = _hasSavedHours;
  late bool _active = widget.branch?['status'] != 'inactive';
  late String? _coverUrl = widget.branch?['coverUrl'] as String?;
  late final String _initialDraft;
  bool _busy = false;
  bool _uploading = false;
  bool _idConflict = false;
  String? _error;
  String? _coverError;
  String? _selectedCover;
  Uint8List? _selectedPreview;
  bool _coverUploadFailed = false;
  bool _pickingLocation = false;
  LatLng? _locationDraft;
  Future<bool>? _discardDialog;

  bool get _creating => widget.branch == null;
  bool get _locked => _busy || _uploading;
  String get _identity =>
      (widget.branch?['branchId'] as String?) ?? _text('branchId');
  String _text(String key) => _values[key]!.text.trim();

  String get _formDraft => jsonEncode([
        for (final field in _values.values) field.text,
        _active,
        _coverUrl,
        _selectedCover != null,
        _editHours,
        if (_editHours)
          for (final day in _hours) day.draft,
      ]);

  bool get _dirty => _formDraft != _initialDraft;

  @override
  void initState() {
    super.initState();
    _initialDraft = _formDraft;
    widget.onLeaveCheckChanged(_confirmLeave);
  }

  @override
  void dispose() {
    widget.onLeaveCheckChanged(null);
    for (final field in _values.values) {
      field.dispose();
    }
    for (final day in _hours) {
      day.dispose();
    }
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (_locked) return false;
    if (!_dirty) return true;
    return _discardDialog ??= confirmDialog(
      context,
      title: 'Discard branch changes?',
      message: 'Your edits to this branch have not been saved.',
      confirmLabel: 'Discard changes',
      destructive: true,
    ).whenComplete(() => _discardDialog = null);
  }

  Future<void> _cancel() async {
    if (await _confirmLeave() && mounted) widget.onCancel();
  }

  static bool _startsWith(Uint8List bytes, List<int> signature) =>
      bytes.length >= signature.length &&
      Iterable<int>.generate(signature.length)
          .every((index) => bytes[index] == signature[index]);

  Future<void> _uploadCover({String? retry}) async {
    if (_locked) return;
    setState(() {
      _uploading = true;
      _coverError = null;
    });
    var pickedValidImage = false;
    try {
      final encoded = retry ?? await widget.pickCover!();
      if (!mounted || encoded == null) return;
      final bytes = base64Decode(encoded);
      if (bytes.length > _coverLimit ||
          (!_startsWith(bytes, const [137, 80, 78, 71, 13, 10, 26, 10]) &&
              !_startsWith(bytes, const [255, 216, 255]))) {
        throw const FormatException('Unsupported branch cover');
      }
      pickedValidImage = true;
      setState(() {
        _selectedCover = encoded;
        _selectedPreview = bytes;
        _coverUploadFailed = false;
        _error = null;
      });
      final response = await widget.request({
        'action': 'uploadBranchCover',
        'dataBase64': encoded,
      });
      final url = response['url'];
      if (url is! String || url.isEmpty) {
        throw StateError('Branch cover URL unavailable.');
      }
      if (mounted) setState(() => _coverUrl = url);
    } catch (_) {
      if (mounted) {
        setState(() {
          if (pickedValidImage) _coverUploadFailed = true;
          _coverError = _coverUploadFailed
              ? 'Cover upload failed. Retry or discard the selected cover.'
              : 'Choose a valid JPG or PNG up to 2 MB.';
        });
      }
    } finally {
      if (mounted) {
        // A canceled replacement keeps any previous failed upload actionable.
        setState(() {
          _uploading = false;
          if (_coverUploadFailed) {
            _coverError ??=
                'Cover upload failed. Retry or discard the selected cover.';
          }
        });
      }
    }
  }

  LatLng? get _coordinates => branchMapPoint({
        'latitude': double.tryParse(_text('latitude')),
        'longitude': double.tryParse(_text('longitude')),
      });

  void _startLocationPicker() {
    FocusScope.of(context).unfocus();
    setState(() {
      _locationDraft = _coordinates;
      _pickingLocation = true;
    });
  }

  void _confirmLocation() {
    final selected = _locationDraft;
    if (_busy || selected == null) return;
    setState(() {
      _values['latitude']!.text = selected.latitude.toStringAsFixed(6);
      _values['longitude']!.text = selected.longitude.toStringAsFixed(6);
      _locationDraft = null;
      _pickingLocation = false;
      _error = null;
    });
  }

  List<String> get _facilities => _text('facilities')
      .split(',')
      .map((facility) => facility.trim())
      .where((facility) => facility.isNotEmpty)
      .toList();

  String? _validateData(String key) {
    final value = _text(key);
    if (key == 'branchId') {
      if (!_idShape.hasMatch(_identity)) {
        return 'Enter a branch ID using letters, numbers, hyphens or underscores.';
      }
      if (_idConflict) return 'This branch ID already exists.';
    }
    if (key == 'displayName' && (value.isEmpty || value.length > 120)) {
      return 'Enter a branch name of up to 120 characters.';
    }
    if (_optionalTextFields.contains(key) && value.length > 1000) {
      return 'Use 1,000 characters or fewer.';
    }
    if (key == 'facilities') {
      final facilities = _facilities;
      if (facilities.length > 30 ||
          facilities.any((name) => name.length > 80)) {
        return 'Use up to 30 facilities, each 80 characters or fewer.';
      }
    }
    return null;
  }

  List<Map<String, Object>>? _schedule() {
    final schedule = <Map<String, Object>>[];
    for (var index = 0; index < _hours.length; index++) {
      final day = _hours[index];
      switch (day.mode) {
        case _BranchDayMode.closed:
          schedule.add({'closed': true});
        case _BranchDayMode.allDay:
          schedule.add({'allDay': true});
        case _BranchDayMode.hours:
          final opens = day.opens.text.trim();
          final closes = day.closes.text.trim();
          if (!_timeShape.hasMatch(opens) ||
              !_timeShape.hasMatch(closes) ||
              opens == closes) {
            setState(() => _error =
                'Enter distinct HH:mm opening and closing times for ${_weekdayNames[index]}.');
            return null;
          }
          schedule.add({'open': opens, 'close': closes});
        case null:
          setState(() => _error =
              'Choose a schedule for ${_weekdayNames[index]} or leave hours unset.');
          return null;
      }
    }
    return schedule;
  }

  Future<void> _save() async {
    if (_locked) return;
    FocusScope.of(context).unfocus();
    if (_coverUploadFailed) {
      setState(() => _error =
          'Retry the selected cover upload or discard it before saving.');
      return;
    }
    if (_pickingLocation) {
      setState(() => _error = 'Confirm or cancel the location selection.');
      return;
    }
    if (!_form.currentState!.validate()) {
      final firstInvalid =
          _labels.keys.map(_validateData).whereType<String>().first;
      setState(() => _error = firstInvalid);
      return;
    }
    final point = _coordinates;
    if (point == null &&
        (_text('latitude').isNotEmpty || _text('longitude').isNotEmpty)) {
      setState(() => _error = 'Enter valid latitude and longitude.');
      return;
    }
    final schedule = _editHours ? _schedule() : null;
    if (_editHours && schedule == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.request({
        'action': 'save',
        'branchId': _identity,
        'create': _creating,
        'branch': {
          'displayName': _text('displayName'),
          for (final key in _optionalTextFields) key: _text(key),
          'latitude': point?.latitude,
          'longitude': point?.longitude,
          'status': _active ? 'active' : 'inactive',
          if (_coverUrl != null) 'coverUrl': _coverUrl,
          if (schedule != null) 'openingHours': schedule,
          'facilities': _facilities,
        },
      });
      if (mounted) widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      final code = error is BranchSaveException ? error.code : null;
      setState(() {
        _busy = false;
        _idConflict = code == 'already-exists';
        _error = switch (code) {
          'already-exists' => 'This branch ID already exists.',
          'permission-denied' => 'Your account cannot save branches.',
          'not-found' => 'This branch no longer exists.',
          _ => 'Branch could not be saved. Check the details and retry.',
        };
      });
      if (_idConflict) _form.currentState?.validate();
    }
  }

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        errorMaxLines: 3,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      );

  Widget _field(String key,
      {int lines = 1, String? hint, bool unavailable = false}) {
    return TextFormField(
      key: ValueKey('branch-editor-$key'),
      controller: _values[key],
      enabled: !_busy && !unavailable,
      readOnly: key == 'branchId' && !_creating,
      maxLines: lines,
      keyboardType: switch (key) {
        'contactEmail' => TextInputType.emailAddress,
        'contactPhone' => TextInputType.phone,
        'latitude' ||
        'longitude' =>
          const TextInputType.numberWithOptions(decimal: true, signed: true),
        _ => lines > 1 ? TextInputType.multiline : TextInputType.text,
      },
      decoration: _decoration(_labels[key]!, hint: hint),
      validator: (_) => _validateData(key),
      onChanged: (_) => setState(() {
        if (key == 'branchId') _idConflict = false;
        _error = null;
      }),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _fieldPair(Widget first, Widget second, {double breakpoint = 360}) =>
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 14), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      });

  TextStyle? get _noteStyle =>
      Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft);

  Widget _note(String label) => Text(label, style: _noteStyle);

  Widget _basic() => _section('Basic information', [
        _field('displayName'),
        const SizedBox(height: 16),
        _field('branchId'),
        const SizedBox(height: 6),
        _note(_creating
            ? 'Use 1–128 letters, numbers, hyphens or underscores. This ID links the branch to bookings, equipment and visit history.'
            : 'This permanent ID links the branch to bookings, equipment and visit history.'),
        const SizedBox(height: 16),
        _field('description', lines: 3),
      ]);

  Widget _address() => _section('Address', [
        _field('address', lines: 2),
        const SizedBox(height: 16),
        _fieldPair(_field('city'), _field('state')),
        const SizedBox(height: 16),
        _fieldPair(_field('postalCode'), _field('country')),
      ]);

  Widget _contact() => _section('Contact details', [
        _fieldPair(_field('contactPhone'), _field('contactEmail')),
      ]);

  Widget _facilitiesSection() => _section('Facilities', [
        _field('facilities', lines: 2),
        const SizedBox(height: 6),
        _note('Separate facilities with commas.'),
      ]);

  Widget _status() => _section('Branch status', [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active branch'),
          subtitle: Text(_active ? 'Active' : 'Inactive'),
          value: _active,
          onChanged: _busy
              ? null
              : (value) => setState(() {
                    _active = value;
                    _error = null;
                  }),
        ),
        _note(_active
            ? 'Members can find and select active branches. Opening hours determine when the gym is open.'
            : 'Inactive branches are hidden from member discovery and cannot be used for new assignments or new gym check-in codes.'),
      ]);

  Widget _hoursField(int index, {required bool open}) {
    final day = _hours[index];
    return TextFormField(
      key: ValueKey(('branch-day-time', index, open)),
      controller: open ? day.opens : day.closes,
      enabled: !_busy,
      keyboardType: TextInputType.datetime,
      decoration: _decoration(open ? 'Opens' : 'Closes', hint: 'HH:mm'),
      onChanged: (_) => setState(() => _error = null),
    );
  }

  Widget _hoursRow(int index) {
    final day = _hours[index];
    final name = _weekdayNames[index];
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: LayoutBuilder(builder: (context, constraints) {
        final dayName = Text(name);
        final mode = DropdownButtonFormField<_BranchDayMode>(
          key: ValueKey(('branch-day-mode', index, _editHours)),
          initialValue: day.mode,
          isExpanded: true,
          decoration: _decoration('$name schedule'),
          items: [
            for (final value in _BranchDayMode.values)
              DropdownMenuItem(value: value, child: Text(value.label)),
          ],
          onChanged: _busy
              ? null
              : (value) => setState(() {
                    day.mode = value;
                    _error = null;
                  }),
        );
        final times = day.mode == _BranchDayMode.hours
            ? _fieldPair(
                _hoursField(index, open: true),
                _hoursField(index, open: false),
                breakpoint: 180,
              )
            : null;
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              dayName,
              const SizedBox(height: 8),
              mode,
              if (times != null) ...[const SizedBox(height: 12), times],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 90,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: dayName,
                )),
            SizedBox(width: 160, child: mode),
            const SizedBox(width: 12),
            Expanded(child: times ?? const SizedBox.shrink()),
          ],
        );
      }),
    );
  }

  Widget _openingHours() => _section('Opening hours', [
        _note(
            'Malaysia time (Asia/Kuala_Lumpur). Set all seven days. A closing time before the opening time continues into the following day.'),
        if (!_hasSavedHours)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Set opening hours'),
            subtitle: !_editHours ? const Text('Hours not set') : null,
            value: _editHours,
            onChanged: _busy
                ? null
                : (value) => setState(() {
                      _editHours = value;
                      _error = null;
                    }),
          ),
        if (_editHours)
          for (var day = 0; day < _weekdayNames.length; day++) _hoursRow(day),
      ]);

  Widget _coverFallback(String message) => ColoredBox(
        color: AppColors.surfaceAlt,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image_outlined, color: AppColors.inkSoft),
                const SizedBox(height: 6),
                Text(message, style: _noteStyle, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );

  Widget _coverPreview() {
    final preview = _selectedPreview;
    if (preview != null) {
      return Image.memory(
        preview,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            _coverFallback('Cover preview unavailable'),
      );
    }
    final url = _coverUrl;
    if (url == null || url.isEmpty) return _coverFallback('No cover image');
    return Image.network(
      url,
      key: ValueKey((_identity, url)),
      fit: BoxFit.cover,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, image, progress) =>
          progress == null ? image : _coverFallback('Loading cover…'),
      errorBuilder: (context, error, stack) =>
          _coverFallback('Cover preview unavailable'),
    );
  }

  Widget _cover() => _section('Branch cover', [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _coverPreview(),
          ),
        ),
        const SizedBox(height: 10),
        _note(_uploading
            ? 'Uploading selected cover…'
            : _coverUploadFailed
                ? 'Selected image · upload incomplete'
                : _selectedPreview != null
                    ? 'Uploaded · save the branch to use this cover'
                    : _coverUrl?.isNotEmpty == true
                        ? 'Saved branch cover'
                        : 'JPG or PNG, up to 2 MB.'),
        if (widget.pickCover != null) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: _locked ? null : _uploadCover,
              icon: const Icon(Icons.image_outlined),
              label: Text(_uploading
                  ? 'Uploading…'
                  : _coverUrl?.isNotEmpty == true
                      ? 'Replace cover'
                      : 'Upload cover'),
            ),
            if (_coverUploadFailed) ...[
              TextButton(
                onPressed:
                    _locked ? null : () => _uploadCover(retry: _selectedCover),
                child: const Text('Retry upload'),
              ),
              TextButton(
                onPressed: _locked
                    ? null
                    : () => setState(() {
                          _selectedPreview = null;
                          _selectedCover = null;
                          _coverUploadFailed = false;
                          _coverError = null;
                          _error = null;
                        }),
                child: const Text('Discard selected cover'),
              ),
            ],
          ]),
        ],
        if (_coverError case final String message)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _errorText(message)),
      ]);

  Widget _location() {
    final coordinates = _coordinates;
    final saved = branchMapPoint(widget.branch ?? const {});
    final hasInput =
        _text('latitude').isNotEmpty || _text('longitude').isNotEmpty;
    final draft = _locationDraft;
    return _section('Map location', [
      _note('The map pin and street address are saved separately.'),
      const SizedBox(height: 14),
      _fieldPair(
        _field('latitude', unavailable: _pickingLocation),
        _field('longitude', unavailable: _pickingLocation),
        breakpoint: 220,
      ),
      const SizedBox(height: 10),
      if (!_pickingLocation) ...[
        if (saved != null && coordinates == saved) ...[
          BranchMap(
            key: const ValueKey('branch-saved-location-preview'),
            pin: saved,
            height: 180,
          ),
          const SizedBox(height: 10),
        ],
        _note(coordinates != null
            ? coordinates == saved
                ? 'Saved coordinates'
                : 'Coordinates ready to save'
            : hasInput
                ? 'Coordinates are incomplete or invalid'
                : saved == null
                    ? 'No location set'
                    : 'Save the branch to clear its location'),
        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _startLocationPicker,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Pick Location on Map'),
          ),
        ),
      ] else ...[
        _note('Tap the map or drag the marker to choose a location.'),
        const SizedBox(height: 8),
        BranchMap(
          pin: draft,
          onPin: (point) {
            final valid = branchMapPoint({
              'latitude': point.latitude,
              'longitude': point.longitude,
            });
            if (valid != null) setState(() => _locationDraft = valid);
          },
        ),
        const SizedBox(height: 8),
        _note(draft == null
            ? 'No coordinates selected'
            : 'Latitude ${draft.latitude.toStringAsFixed(6)} · Longitude ${draft.longitude.toStringAsFixed(6)}'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonal(
            onPressed: draft == null ? null : _confirmLocation,
            child: const Text('Confirm Location'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _pickingLocation = false;
              _locationDraft = null;
              _error = null;
            }),
            child: const Text('Cancel location selection'),
          ),
        ]),
      ],
    ]);
  }

  Widget _errorText(String message) => Semantics(
        liveRegion: true,
        child: Text(message,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );

  Widget _heading() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: _locked ? null : _cancel,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Back to branches'),
          ),
          const SizedBox(height: 8),
          Text(_creating ? 'Add Branch' : 'Edit Branch',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            _creating
                ? 'Set up a gym location and its operating details.'
                : 'Update the profile and operating details for ${widget.branch?['displayName'] ?? _identity}.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (!_creating) ...[
            const SizedBox(height: 8),
            _note(
                '$_identity · ${widget.branch?['status'] == 'inactive' ? 'Inactive' : 'Active'}'),
          ],
        ],
      );

  Widget _columns() => LayoutBuilder(builder: (context, constraints) {
        final left = _sectionStack([
          _basic(),
          _address(),
          _contact(),
          _openingHours(),
          _facilitiesSection(),
          _status()
        ]);
        final right = _sectionStack([_cover(), _location()]);
        if (constraints.maxWidth < 860) {
          return _sectionStack([left, right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: left),
            const SizedBox(width: 20),
            Expanded(flex: 2, child: right),
          ],
        );
      });

  Widget _sectionStack(List<Widget> sections) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: sections,
      );

  Widget _footer(double padding) => ColoredBox(
        color: AppColors.surface,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.hairline)),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1260),
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: padding, vertical: 10),
                child: LayoutBuilder(builder: (context, constraints) {
                  final actions = Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _locked ? null : _cancel,
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: _locked ? null : _save,
                        child: Text(_busy
                            ? 'Saving…'
                            : _creating
                                ? 'Save Branch'
                                : 'Save Changes'),
                      ),
                    ],
                  );
                  final status = switch ((_error, _dirty)) {
                    (final String message, _) => _errorText(message),
                    (null, true) => _note('Unsaved changes'),
                    _ => const SizedBox.shrink(),
                  };
                  if (constraints.maxWidth < 520) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [status, actions],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: status),
                      const SizedBox(width: 12),
                      actions,
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.bg,
        child: LayoutBuilder(builder: (context, constraints) {
          final padding = constraints.maxWidth < 520 ? 16.0 : 28.0;
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('branch-editor-scroll'),
                  padding: EdgeInsets.fromLTRB(padding, 22, padding, 30),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1204),
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _heading(),
                            const SizedBox(height: 20),
                            _columns()
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _footer(padding),
            ],
          );
        }),
      );
}
