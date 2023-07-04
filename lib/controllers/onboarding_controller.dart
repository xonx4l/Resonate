import 'dart:developer';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:resonate/utils/constants.dart';
import 'package:resonate/utils/enums/gender.dart';

import 'auth_state_controller.dart';

class OnboardingController extends GetxController {
  final ImagePicker _imagePicker = ImagePicker();
  AuthStateContoller authStateController = Get.find<AuthStateContoller>();
  late final Storage storage;
  late final Databases databases;

  RxBool isLoading = false.obs;
  String? profileImagePath;

  TextEditingController nameController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  TextEditingController imageController =
      TextEditingController(text: userProfileImagePlaceholderUrl);
  TextEditingController genderController =
      TextEditingController(text: Gender.male.name);
  TextEditingController dobController = TextEditingController(text: "");

  final GlobalKey<FormState> userOnboardingFormKey = GlobalKey<FormState>();

  Rx<bool> usernameAvailable = false.obs;

  @override
  void onInit() async {
    super.onInit();
    storage = Storage(authStateController.client);
    databases = Databases(authStateController.client);
  }

  Future<void> chooseDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: Get.context!,
      initialDate: DateTime.now(),
      firstDate: DateTime(1800),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      dobController.text =
          DateFormat("dd-MM-yyyy").format(pickedDate).toString();
    }
  }

  void setGender(Gender gender) {
    genderController.text = gender.name;
    update();
  }

  Future<void> saveProfile() async {
    if (!userOnboardingFormKey.currentState!.validate()) {
      return;
    }
    var usernameAvail = await isUsernameAvailable(usernameController.text);
    if (!usernameAvail){
      usernameAvailable.value = false;
      Get.snackbar("Username Unavailable!", "This username is invalid or either taken already.", snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      isLoading.value = true;

      // Update username collection
      databases.createDocument(
        databaseId: 'user-data',
        collectionId: 'usernames',
        documentId: usernameController.text,
        data: {
          "uid": authStateController.uid
        },
      );

      //Update User Meta Data
      if (profileImagePath!=null){
        final profileImage = await storage.createFile(bucketId: userProfileImageBucketId, fileId: ID.unique(), file: InputFile.fromPath(path: profileImagePath!, filename: "${authStateController.email}.jpeg"));
        imageController.text = "${APPWRITE_ENDPOINT}/storage/buckets/$userProfileImageBucketId/files/${profileImage.$id}/view?project=${APPWRITE_PROJECT_ID}";
      }
      await authStateController.account.updateName(name: nameController.text);
      await authStateController.account.updatePrefs(prefs: {
        "username": usernameController.text,
        "profileImageUrl": imageController.text,
        "dob": dobController.text,
        "isUserProfileComplete": true
      });
      await authStateController.setUserProfileData();

      Get.snackbar("Saved Successfully", "");
    } catch (e) {
      log(e.toString());
      Get.snackbar("Error!", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> pickImage() async {
    try {
      XFile? file = await _imagePicker.pickImage(
          source: ImageSource.gallery, maxHeight: 400, maxWidth: 400);
      if (file == null) return;
      profileImagePath = file.path;
      update();
    } catch (e) {
      log(e.toString());
    }
  }

  Future<bool> isUsernameAvailable(String username) async {
    try{
      final document = await databases.getDocument(
        databaseId: 'user-data',
        collectionId: 'usernames',
        documentId: username,
      );
      return false;
    }catch(e){
      log(e.toString());
      return true;
    }
  }
}