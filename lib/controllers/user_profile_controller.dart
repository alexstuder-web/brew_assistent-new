import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

import '../main.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';

class UserProfileController extends ChangeNotifier {
  final TextEditingController userNameCtrl = TextEditingController();
  final FocusNode userNameFocusNode = FocusNode();
  final TextEditingController defaultBatchCtrl = TextEditingController();

  final UserProfileRepository profileRepository;

  String? newAvatarBase64;
  String selectedLanguage = 'de';
  
  bool isSaving = false;
  bool isLoadingProfile = true;
  String? loadError;
  String? userNameError;
  UserProfile? loadedProfile;

  static String get profileId => UserProfileService.currentUserId;

  UserProfileController({UserProfileRepository? repository})
      : profileRepository = repository ?? UserProfileService() {
    loadProfile();
  }

  @override
  void dispose() {
    userNameCtrl.dispose();
    userNameFocusNode.dispose();
    defaultBatchCtrl.dispose();
    super.dispose();
  }

  void clearUserNameError() {
    if (userNameError != null) {
      userNameError = null;
      notifyListeners();
    }
  }

  void setLanguage(String lang) {
    selectedLanguage = lang;
    notifyListeners();
  }

  Future<void> loadProfile() async {
    try {
      final profile = await profileRepository.fetchProfile(profileId);
      loadedProfile = profile;
      if (profile != null) {
        userNameCtrl.text = profile.name;
        defaultBatchCtrl.text = profile.defaultBatchLiters?.toString() ?? '';
        selectedLanguage = profile.language;
      }
      isLoadingProfile = false;
      loadError = null;
      notifyListeners();
    } catch (e) {
      isLoadingProfile = false;
      loadError = e.toString();
      notifyListeners();
    }
  }

  Future<bool> saveProfile(BuildContext context, {bool showFeedback = true}) async {
    FocusScope.of(context).unfocus();
    final double? defaultBatch =
        double.tryParse(defaultBatchCtrl.text.replaceAll(',', '.'));

    final profile = UserProfile(
      id: profileId,
      name: userNameCtrl.text.trim(),
      avatarBlob: newAvatarBase64 ?? loadedProfile?.avatarBlob,
      defaultBatchLiters: defaultBatch,
      raptUserId: loadedProfile?.raptUserId,
      raptApiKey: loadedProfile?.raptApiKey,
      brewfatherUserId: loadedProfile?.brewfatherUserId,
      brewfatherApiKey: loadedProfile?.brewfatherApiKey,
      brewfatherSyncEnabled: loadedProfile?.brewfatherSyncEnabled ?? false,
      language: selectedLanguage,
    );

    isSaving = true;
    notifyListeners();

    var success = false;
    try {
      await profileRepository.saveProfile(profile);
      loadedProfile = profile;
      if (!context.mounted) return success;
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil gespeichert')),
        );
      }
      if (context.mounted) {
        BrewMateApp.setLocale(context, Locale(selectedLanguage));
      }
      success = true;
    } catch (e) {
      if (!context.mounted) return success;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
    } finally {
      isSaving = false;
      notifyListeners();
    }
    return success;
  }

  Future<void> uploadAvatar(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      Uint8List? fileBytes = file.bytes;

      if (fileBytes == null) return;

      isSaving = true;
      notifyListeners();

      final image = img.decodeImage(fileBytes);
      if (image == null) throw Exception('Bild konnte nicht dekodiert werden');

      img.Image resized = image;
      if (image.width > 512 || image.height > 512) {
        resized = img.copyResize(
          image,
          width: image.width >= image.height ? 512 : null,
          height: image.height > image.width ? 512 : null,
        );
      }

      final jpgBytes = img.encodeJpg(resized, quality: 80);
      final base64Image = base64Encode(jpgBytes);

      newAvatarBase64 = base64Image;
      notifyListeners();

      if (context.mounted) {
        await saveProfile(context, showFeedback: false);
      }
    } catch (e) {
      isSaving = false;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload fehlgeschlagen: $e')),
        );
      }
    }
  }

  bool ensureUserName(BuildContext context) {
    final name = userNameCtrl.text.trim();
    if (name.isNotEmpty) {
      if (userNameError != null) {
        userNameError = null;
        notifyListeners();
      }
      return true;
    }
    userNameError = 'Name erforderlich';
    notifyListeners();
    userNameFocusNode.requestFocus();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name fehlt'),
        content: const Text(
          'Bitte gib zuerst einen Profilnamen ein, bevor du weitere Ressourcen verwaltest.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }

  Future<bool> saveProfileIfNeeded(BuildContext context) async {
    if (isSaving) return false;
    final success = await saveProfile(context, showFeedback: false);
    return success;
  }
}
