// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled1/core/auth_validators.dart';
import 'package:untitled1/viewmodels/auth_viewmodel.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

class FakeAuthCredential extends Fake implements AuthCredential {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseAuth auth;
  late MockFirebaseFirestore firestore;
  late MockCollectionReference collection;
  late MockDocumentReference document;
  late MockDocumentSnapshot snapshot;
  late MockUserCredential credential;
  late MockUser user;
  late MockGoogleSignIn googleSignIn;
  late AuthViewModel viewModel;

  setUpAll(() {
    registerFallbackValue(FakeAuthCredential());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    auth = MockFirebaseAuth();
    firestore = MockFirebaseFirestore();
    collection = MockCollectionReference();
    document = MockDocumentReference();
    snapshot = MockDocumentSnapshot();
    credential = MockUserCredential();
    user = MockUser();
    googleSignIn = MockGoogleSignIn();

    when(() => firestore.collection('users')).thenReturn(collection);
    when(() => collection.doc(any())).thenReturn(document);
    when(() => document.get()).thenAnswer((_) async => snapshot);
    when(() => credential.user).thenReturn(user);
    when(() => user.uid).thenReturn('uid-1');
    when(() => snapshot.exists).thenReturn(true);
    when(() => snapshot.data())
        .thenReturn({'role': 'Reader', 'is_locked': false});
    when(() => auth.signOut()).thenAnswer((_) async {});
    when(() => googleSignIn.signOut()).thenAnswer((_) async => null);

    viewModel = AuthViewModel(
      auth: auth,
      firestore: firestore,
      googleSignIn: googleSignIn,
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('AuthValidators', () {
    test('validates email, password and confirmation', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email('sai-email'), isNotNull);
      expect(AuthValidators.email('reader@example.com'), isNull);
      expect(AuthValidators.password('123'), isNotNull);
      expect(AuthValidators.password('123456'), isNull);
      expect(AuthValidators.confirmPassword('123456', '654321'), isNotNull);
      expect(AuthValidators.confirmPassword('123456', '123456'), isNull);
    });

    test('accepts optional valid Vietnamese phone number', () {
      expect(AuthValidators.phone(''), isNull);
      expect(AuthValidators.phone('0912345678'), isNull);
      expect(AuthValidators.phone('+84912345678'), isNull);
      expect(AuthValidators.phone('123'), isNotNull);
    });
  });

  group('signIn', () {
    setUp(() {
      when(
        () => auth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => credential);
    });

    test('allows an unlocked Reader account', () async {
      final result = await viewModel.signIn(
        ' reader@example.com ',
        '123456',
        rememberMe: false,
      );

      expect(result, isTrue);
      verify(
        () => auth.signInWithEmailAndPassword(
          email: 'reader@example.com',
          password: '123456',
        ),
      ).called(1);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('remember_login'), isFalse);
    });

    test('signs out and rejects a locked account', () async {
      when(() => snapshot.data()).thenReturn({'is_locked': true});

      expect(
        () => viewModel.signIn('reader@example.com', '123456'),
        throwsA(isA<Exception>()),
      );
      await Future<void>.delayed(Duration.zero);
      verify(() => auth.signOut()).called(1);
    });

    test('rejects an account without a Firestore profile', () async {
      when(() => snapshot.exists).thenReturn(false);

      await expectLater(
        () => viewModel.signIn('reader@example.com', '123456'),
        throwsA(isA<Exception>()),
      );
      verify(() => auth.signOut()).called(1);
    });
  });

  test('signOut clears the remembered-session preference', () async {
    SharedPreferences.setMockInitialValues({'remember_login': true});

    await viewModel.signOut();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('remember_login'), isFalse);
    verify(() => auth.signOut()).called(1);
    verify(() => googleSignIn.signOut()).called(1);
  });

  test('register creates a Reader profile and display name', () async {
    when(
      () => auth.createUserWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => credential);
    when(() => user.updateDisplayName(any())).thenAnswer((_) async {});
    when(() => document.set(any())).thenAnswer((_) async {});

    await viewModel.register(
      fullName: '  NgườI Đọc  ',
      email: 'reader@example.com',
      password: '123456',
    );

    verify(() => user.updateDisplayName('NgườI Đọc')).called(1);
    final captured =
        verify(() => document.set(captureAny())).captured.single
            as Map<String, dynamic>;
    expect(captured['full_name'], 'NgườI Đọc');
    expect(captured['role'], 'Reader');
    expect(captured['is_locked'], isFalse);
    expect(captured['favorite_categories'], isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('remember_login'), isFalse);
  });

  test('Google sign-in creates a profile for a new user', () async {
    final googleAccount = MockGoogleSignInAccount();
    final googleAuthentication = MockGoogleSignInAuthentication();
    when(() => googleSignIn.signIn()).thenAnswer((_) async => googleAccount);
    when(() => googleAccount.authentication)
        .thenAnswer((_) async => googleAuthentication);
    when(() => googleAuthentication.accessToken).thenReturn('access-token');
    when(() => googleAuthentication.idToken).thenReturn('id-token');
    when(() => auth.signInWithCredential(any()))
        .thenAnswer((_) async => credential);
    var profileExists = false;
    when(() => snapshot.exists).thenAnswer((_) => profileExists);
    when(() => user.displayName).thenReturn('Google Reader');
    when(() => user.email).thenReturn('google@example.com');
    when(() => user.phoneNumber).thenReturn(null);
    when(() => user.photoURL).thenReturn(null);
    when(() => document.set(any())).thenAnswer((_) async {
      profileExists = true;
    });

    final result = await viewModel.signInWithGoogle();

    expect(result, isTrue);
    verify(() => auth.signInWithCredential(any())).called(1);
    final captured =
        verify(() => document.set(captureAny())).captured.single
            as Map<String, dynamic>;
    expect(captured['email'], 'google@example.com');
    expect(captured['role'], 'Reader');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('remember_login'), isFalse);
  });

  test('password reset uses the entered email', () async {
    when(() => auth.sendPasswordResetEmail(email: any(named: 'email')))
        .thenAnswer((_) async {});

    await viewModel.sendPasswordResetEmail(' reader@example.com ');

    verify(() => auth.sendPasswordResetEmail(email: 'reader@example.com'))
        .called(1);
  });

  test('change password reauthenticates before updating', () async {
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.email).thenReturn('reader@example.com');
    when(() => user.reauthenticateWithCredential(any()))
        .thenAnswer((_) async => credential);
    when(() => user.updatePassword(any())).thenAnswer((_) async {});

    await viewModel.changePassword(
      currentPassword: 'old-password',
      newPassword: 'new-password',
    );

    verifyInOrder([
      () => user.reauthenticateWithCredential(any()),
      () => user.updatePassword('new-password'),
    ]);
  });

  test('email change reauthenticates before sending verification', () async {
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.email).thenReturn('reader@example.com');
    when(() => user.reauthenticateWithCredential(any()))
        .thenAnswer((_) async => credential);
    when(() => user.verifyBeforeUpdateEmail(any())).thenAnswer((_) async {});

    await viewModel.requestEmailChange(
      newEmail: ' new-email@example.com ',
      currentPassword: 'current-password',
    );

    verifyInOrder([
      () => user.reauthenticateWithCredential(any()),
      () => user.verifyBeforeUpdateEmail('new-email@example.com'),
    ]);
  });

  test('auth errors have safe localized messages', () {
    expect(
      authErrorMessage(FirebaseAuthException(code: 'invalid-credential')),
      'Email hoặc mật khẩu không đúng.',
    );
    expect(
      authErrorMessage(FirebaseAuthException(code: 'email-already-in-use')),
      'Email này đã được sử dụng.',
    );
    expect(
      authErrorMessage(FirebaseAuthException(code: 'unauthorized-domain')),
      contains('localhost'),
    );
    expect(
      authErrorMessage(FirebaseAuthException(code: 'operation-not-allowed')),
      'Phương thức đăng nhập này chưa được bật trong Firebase Authentication.',
    );
    expect(
      authErrorMessage(FirebaseAuthException(code: 'popup-blocked')),
      contains('cửa sổ bật lên'),
    );
    expect(
      authErrorMessage(TimeoutException(null)),
      contains('Không nhận được phản hồi từ Firebase'),
    );
  });
}
