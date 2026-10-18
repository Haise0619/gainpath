import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Uses authenticated bytes only. No public download URL is created or stored.
class AdminAccountAvatar extends StatefulWidget {
  const AdminAccountAvatar({super.key, required this.live});
  final bool live;
  @override
  State<AdminAccountAvatar> createState() => _AdminAccountAvatarState();
}

class _AdminAccountAvatarState extends State<AdminAccountAvatar> {
  Future<Uint8List?>? _photo;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !widget.live) return;
    _started = true;
    try {
      _photo = context
          .read<AdminAccountContactRepository>()
          .loadCurrentPhoto()
          .catchError((_) => null);
    } catch (_) {
      _photo = null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
      future: _photo,
      builder: (_, snapshot) => CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.primaryTint,
          child: snapshot.data == null
              ? const Icon(Icons.person_rounded,
                  size: 18, color: AppColors.primary)
              : ClipOval(
                  child: Image.memory(snapshot.data!,
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                      cacheWidth: 68,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.person_rounded,
                          size: 18,
                          color: AppColors.primary)))));
}
