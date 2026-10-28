// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_async/fake_async.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:untitled1/models/user_model.dart';
import 'package:untitled1/viewmodels/profile_viewmodel.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockUser extends Mock implements User {}

class MockXFile extends Mock implements XFile {}

void main() {
  late MockFirebaseAuth auth;
  late MockFirebaseFirestore firestore;
  late MockCollectionReference collection;
  late MockDocumentReference document;
  late MockUser user;
  late ProfileViewModel viewModel;

  setUp(() {
    auth = MockFirebaseAuth();
    firestore = MockFirebaseFirestore();
    collection = MockCollectionReference();
    document = MockDocumentReference();
    user = MockUser();

    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('uid-1');
    when(() => user.email).thenReturn('reader@example.com');
    when(() => user.updateDisplayName(any())).thenAnswer((_) async {});
    when(() => firestore.collection('users')).thenReturn(collection);
    when(() => collection.doc('uid-1')).thenReturn(document);
    when(() => document.update(any())).thenAnswer((_) async {});

    viewModel = ProfileViewModel(auth: auth, firestore: firestore);
  });

  test(
    'updates profile and favorite categories without changing role',
    () async {
      await viewModel.updateProfile(
        fullName: '  Reader  ',
        phone: ' 0912345678 ',
        favoriteCategories: const ['news', 'technology'],
      );

      verify(() => user.updateDisplayName('Reader')).called(1);
      final captured =
          verify(() => document.update(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['full_name'], 'Reader');
      expect(captured['phone'], '0912345678');
      expect(captured['favorite_categories'], ['news', 'technology']);
      expect(captured.containsKey('role'), isFalse);
      expect(captured.containsKey('avatar_url'), isFalse);
    },
  );

  test('stores avatar as a data URL in Firestore', () async {
    final file = MockXFile();
    final bytes = Uint8List.fromList([1, 2, 3]);
    when(() => file.length()).thenAnswer((_) async => bytes.length);
    when(() => file.readAsBytes()).thenAnswer((_) async => bytes);
    when(() => file.mimeType).thenReturn('image/jpeg');

    await viewModel.updateProfile(
      fullName: 'Reader',
      phone: '',
      favoriteCategories: const [],
      avatarFile: file,
    );

    final captured =
        verify(() => document.update(captureAny())).captured.single
            as Map<String, dynamic>;
    final avatarData = captured['avatar_url'] as String;
    expect(avatarData, startsWith('data:image/jpeg;base64,'));
    expect(base64Decode(avatarData.split(',').last), bytes);
    verifyNever(() => user.updatePhotoURL(any()));
  });

  test('rejects a compressed avatar larger than 500 KB', () async {
    final file = MockXFile();
    when(() => file.length())
        .thenAnswer((_) async => ProfileViewModel.maxAvatarBytes + 1);

    await expectLater(
      () => viewModel.updateProfile(
        fullName: 'Reader',
        phone: '',
        favoriteCategories: const [],
        avatarFile: file,
      ),
      throwsA(isA<Exception>()),
    );
    verifyNever(() => user.updateDisplayName(any()));
    verifyNever(() => document.update(any()));
  });

  test('stops waiting when Firebase Auth does not respond', () {
    fakeAsync((async) {
      when(() => user.updateDisplayName(any()))
          .thenAnswer((_) => Completer<void>().future);
      Object? error;

      unawaited(
        viewModel
            .updateProfile(
              fullName: 'Reader',
              phone: '',
              favoriteCategories: const [],
            )
            .catchError((Object caughtError) {
              error = caughtError;
            }),
      );
      async.elapse(const Duration(seconds: 20));

      expect(
        error,
        isA<TimeoutException>().having(
          (error) => error.message,
          'message',
          contains('Firebase Auth'),
        ),
      );
      verifyNever(() => document.update(any()));
    });
  });

  test('requires a signed-in user', () async {
    when(() => auth.currentUser).thenReturn(null);

    await expectLater(
      () => viewModel.updateProfile(
        fullName: 'Reader',
        phone: '',
        favoriteCategories: const [],
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('UserModel preserves favorite categories', () {
    final model = UserModel.fromMap({
      'full_name': 'Reader',
      'email': 'reader@example.com',
      'favorite_categories': ['news'],
    }, 'uid-1');

    expect(model.favoriteCategories, ['news']);
    expect(model.toMap()['favorite_categories'], ['news']);
    expect(model.role, 'Reader');
  });
}
