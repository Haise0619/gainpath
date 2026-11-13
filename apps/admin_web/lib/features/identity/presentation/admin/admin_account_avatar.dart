import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class _AvatarPayload {
  const _AvatarPayload({this.bytes, this.url});
  final Uint8List? bytes;
  final String? url;
}

/// Uses authenticated bytes or native Web HTML element when available.
class AdminAccountAvatar extends StatefulWidget {
  const AdminAccountAvatar({super.key, required this.live});
  final bool live;
  @override
  State<AdminAccountAvatar> createState() => _AdminAccountAvatarState();
}

class _AdminAccountAvatarState extends State<AdminAccountAvatar> {
  Future<_AvatarPayload?>? _photo;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !widget.live) return;
    _started = true;
    _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant AdminAccountAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.live && (!oldWidget.live || _photo == null)) {
      _loadPhoto();
    }
  }

  void _loadPhoto() {
    _photo = _fetchAvatar();
  }

  Future<_AvatarPayload?> _fetchAvatar() async {
    try {
      final repo = context.read<AdminAccountContactRepository>();
      final bytes = await repo.loadCurrentPhoto();
      if (bytes != null && bytes.isNotEmpty) {
        return _AvatarPayload(bytes: bytes);
      }
    } catch (_) {}

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final avatarPath = doc.data()?['avatarPath'] as String?;
        if (avatarPath != null && avatarPath.isNotEmpty) {
          try {
            final url =
                await FirebaseStorage.instance.ref(avatarPath).getDownloadURL();
            if (url.isNotEmpty) return _AvatarPayload(url: url);
          } catch (_) {}

          try {
            final data = await FirebaseStorage.instance
                .ref(avatarPath)
                .getData(AccountPhoto.maxBytes);
            if (data != null && data.isNotEmpty) {
              return _AvatarPayload(bytes: data);
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    return null;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_AvatarPayload?>(
      future: _photo,
      builder: (_, snapshot) {
        final payload = snapshot.data;
        Widget? child;
        if (payload?.url != null && payload!.url!.isNotEmpty) {
          child = Image.network(
            payload.url!,
            width: 34,
            height: 34,
            fit: BoxFit.cover,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.person_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          );
        } else if (payload?.bytes != null && payload!.bytes!.isNotEmpty) {
          child = Image.memory(
            payload.bytes!,
            width: 34,
            height: 34,
            fit: BoxFit.cover,
            cacheWidth: 68,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.person_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          );
        }

        return CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.primaryTint,
          child: child == null
              ? const Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: AppColors.primary,
                )
              : ClipOval(child: child),
        );
      });
}
