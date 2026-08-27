import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:image_picker/image_picker.dart";
import "package:duboun/core/api/api_client.dart";
import "package:duboun/core/api/auth_repo.dart";
import "package:duboun/core/api/driver_repo.dart";
import "package:duboun/core/api/error_messages.dart";
import "package:duboun/core/api/ride_repo.dart";
import "package:duboun/core/api/user_repo.dart";
import "package:duboun/core/auth/auth_state.dart";
import "package:duboun/core/models/driver.dart";
import "package:duboun/core/models/ride.dart";
import "package:duboun/core/models/user.dart";
import "package:duboun/core/router/app_router.dart";
import "package:duboun/features/account/account_providers.dart";
import "package:duboun/features/account/account_screen.dart";
import "package:duboun/features/auth/login_screen.dart";
import "package:duboun/features/auth/providers.dart" show userRepoProvider;
import "package:duboun/features/booking/booking_provider.dart"
    show rideRepoProvider;
import "package:duboun/features/deck/deck_provider.dart";
import "package:shared_preferences/shared_preferences.dart";

// --- fixtures -----------------------------------------------------------------

final _png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

Map<String, dynamic> _userJson({
  String? photo,
  String name = "Dara Sok",
  String phone = "+85512999999",
}) =>
    {
      "id": 9,
      "role": "customer",
      "name": name,
      "phone": phone,
      "email": "dara@taxi.demo",
      "photo": photo,
      "rating": "5.0",
      "active": true,
      "fcm_token": null,
    };

AuthState _session({
  String role = "customer",
  String? photo,
  String? phone = "+85512999999",
}) =>
    AuthState(
      token: "jwt",
      role: role,
      name: "Dara Sok",
      email: "dara@taxi.demo",
      phone: phone,
      photo: photo,
    );

User _userModel({
  String? photo,
  String name = "Dara Sok",
  String phone = "+85512999999",
}) =>
    User(
      id: 9,
      role: "customer",
      name: name,
      phone: phone,
      email: "dara@taxi.demo",
      rating: 5,
      active: true,
      photo: photo,
    );

const _vehicle = Driver(
  id: 4,
  userId: 40,
  carModel: "Honda Dream 2020",
  plate: "PP-1A-2345",
  licenseNo: "KH-DL-1111",
  verified: true,
  online: false,
  pricePerKm: 1.25,
);

const _vehicleWithPhoto = Driver(
  id: 4,
  userId: 40,
  carModel: "Honda Dream 2020",
  plate: "PP-1A-2345",
  licenseNo: "KH-DL-1111",
  verified: true,
  online: false,
  pricePerKm: 1.25,
  vehiclePhoto: "/uploads/bike.png",
);

const _vehicleWithGallery = Driver(
  id: 4,
  userId: 40,
  carModel: "Honda Dream 2020",
  plate: "PP-1A-2345",
  licenseNo: "KH-DL-1111",
  verified: true,
  online: false,
  pricePerKm: 1.25,
  vehiclePhoto: "/uploads/bike.png",
  vehiclePhotos: ["/uploads/bike.png", "/uploads/ride.jpg"],
);

const _dara = Driver(
  id: 1,
  userId: 10,
  carModel: "Honda Dream",
  plate: "PP-1A-2345",
  licenseNo: "L-0001",
  verified: true,
  online: true,
  pricePerKm: 1.20,
  name: "Dara Sok",
  rating: 4.8,
  etaMinutes: 4,
);

// --- HTTP seam ----------------------------------------------------------------

/// Fake Dio adapter: captures every RequestOptions, replies a canned envelope.
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this.responder);

  final ResponseBody Function(RequestOptions options) responder;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

class _NeverAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      throw StateError("stub repo must never hit HTTP");

  @override
  void close({bool force = false}) {}
}

ResponseBody _envelope(Map<String, dynamic> data) => ResponseBody.fromString(
      jsonEncode({"success": true, "data": data}),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );

ResponseBody _errEnvelope(String code, String message) =>
    ResponseBody.fromString(
      jsonEncode({
        "success": false,
        "error": {"code": code, "message": message},
      }),
      400,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );

/// Mirrors production wiring: envelope interceptor + bearer token provider.
ApiClient _wired(HttpClientAdapter adapter, {String token = "jwt-1"}) => ApiClient(
      dio: Dio(BaseOptions(validateStatus: (_) => true))..httpClientAdapter = adapter,
      tokenProvider: () => token,
    );

// --- subclass fakes (driver_home_test convention) ------------------------------

class _StubUserRepo extends UserRepo {
  _StubUserRepo() : super(_wired(_NeverAdapter()));

  ApiResult<User>? patchResult;
  ApiResult<User>? uploadResult;
  ApiResult<void>? passwordResult;

  final List<({String name, String phone})> patchCalls = [];
  final List<Uint8List> uploadBytes = [];
  final List<String> uploadNames = [];
  final List<String> uploadMimes = [];
  final List<({String current, String next})> passwordCalls = [];

  @override
  Future<ApiResult<User>> patchMe({String? name, String? phone}) async {
    patchCalls.add((name: name!, phone: phone!));
    return patchResult ??
        ApiResult.ok(_userModel(name: name, phone: phone)); // server echoes
  }

  @override
  Future<ApiResult<User>> uploadAvatar({
    required Uint8List bytes,
    String filename = "avatar.jpg",
    String mimeType = "image/jpeg",
  }) async {
    uploadBytes.add(bytes);
    uploadNames.add(filename);
    uploadMimes.add(mimeType);
    return uploadResult ?? ApiResult.ok(_userModel(photo: "/uploads/fresh.png"));
  }

  @override
  Future<ApiResult<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    passwordCalls.add((current: currentPassword, next: newPassword));
    return passwordResult ?? const ApiResult.ok(null);
  }
}

class _StubDriverRepo extends DriverRepo {
  _StubDriverRepo({this.meResult}) : super(_wired(_NeverAdapter()));

  ApiResult<Driver>? meResult;
  ApiResult<Driver>? updateResult;
  ApiResult<Driver>? photoResult;
  ApiResult<Driver>? photosUploadResult;
  ApiResult<Driver>? removeResult;

  final List<Map<String, dynamic>> updateCalls = [];
  final List<List<XFile>> photosUploadCalls = [];
  final List<int> removeCalls = [];

  @override
  Future<ApiResult<Driver>> me() async =>
      meResult ?? ApiResult.ok(_vehicle);

  @override
  Future<ApiResult<Driver>> updateVehicle({
    String? carModel,
    String? plate,
    String? licenseNo,
    double? pricePerKm,
  }) async {
    updateCalls.add({
      "car_model": carModel,
      "plate": plate,
      "license_no": licenseNo,
      "price_per_km": pricePerKm,
    });
    return updateResult ??
        ApiResult.ok(const Driver(
          id: 4,
          userId: 40,
          carModel: "Honda Dream 2020",
          plate: "PP-9Z-9999",
          licenseNo: "KH-DL-1111",
          verified: true,
          online: false,
          pricePerKm: 1.3,
        ));
  }

  @override
  Future<ApiResult<Driver>> updateVehiclePhoto({
    required Uint8List bytes,
    String filename = "vehicle.jpg",
    String mimeType = "image/jpeg",
  }) async {
    return photoResult ?? const ApiResult.ok(_vehicleWithPhoto);
  }

  @override
  Future<ApiResult<Driver>> uploadPhotos(List<XFile> photos) async {
    photosUploadCalls.add(photos);
    return photosUploadResult ?? const ApiResult.ok(_vehicleWithGallery);
  }

  @override
  Future<ApiResult<Driver>> removePhoto(int index) async {
    removeCalls.add(index);
    // Default server truth after a removal: gallery reduced to the cover.
    return removeResult ?? const ApiResult.ok(_vehicleWithPhoto);
  }
}

/// Records logout dispatches; real updateProfile/adoptUser logic inherited.
class _SpyAuth extends AuthNotifier {
  _SpyAuth(this.seed);

  final AuthState seed;
  int logoutCalls = 0;

  @override
  Future<AuthState> build() async => seed;

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AsyncData(AuthState());
  }
}

class _FakeDeck extends DeckNotifier {
  _FakeDeck(this.cards);

  final List<Driver> cards;

  @override
  Future<DeckState> build() async =>
      DeckState(cards: List.of(cards), swipedLeft: const <int>{});
}

class _StubRideRepo extends RideRepo {
  _StubRideRepo() : super(_wired(_NeverAdapter()));

  @override
  Future<ApiResult<List<Ride>>> mine() async => const ApiResult.ok([]);
}

// --- widget harness -------------------------------------------------------------

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required AuthState session,
  _StubUserRepo? userRepo,
  _StubDriverRepo? driverRepo,
  AvatarPicker? picker,
  VehiclePhotosPicker? multiPicker,
  bool fullRouter = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(overrides: [
    authProvider.overrideWith(() => _SpyAuth(session)),
    userRepoProvider.overrideWithValue(userRepo ?? _StubUserRepo()),
    driverRepoProvider.overrideWithValue(driverRepo ?? _StubDriverRepo()),
    deckProvider.overrideWith(() => _FakeDeck([_dara])),
    rideRepoProvider.overrideWithValue(_StubRideRepo()),
    if (picker != null) avatarPickerProvider.overrideWithValue(picker),
    if (multiPicker != null)
      vehiclePhotosPickerProvider.overrideWithValue(multiPicker),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: fullRouter
          ? Consumer(
              builder: (_, ref, _) => MaterialApp.router(
                routerConfig: ref.watch(appRouterProvider),
              ),
            )
          : const MaterialApp(home: AccountScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group("UserRepo speaks the Task A contract", () {
    test("patchMe PATCHes /api/users/me with {name, phone} and parses the user",
        () async {
      final adapter = _CapturingAdapter(
        (_) => _envelope(_userJson(name: "Dara Two", phone: "+85512345678")),
      );
      final repo = UserRepo(_wired(adapter));

      final result =
          await repo.patchMe(name: "Dara Two", phone: "+85512345678");

      expect(result.isOk, isTrue);
      expect(result.data!.name, "Dara Two");
      expect(result.data!.photo, isNull);
      final req = adapter.requests.single;
      expect(req.method, "PATCH");
      expect(req.path, "/api/users/me");
      expect(req.data, {"name": "Dara Two", "phone": "+85512345678"});
      expect(req.headers["Authorization"], "Bearer jwt-1");
    });

    test("changePassword POSTs snake_case credentials to /users/me/password",
        () async {
      final adapter =
          _CapturingAdapter((_) => _envelope({"updated": true}));
      final repo = UserRepo(_wired(adapter));

      final result = await repo.changePassword(
        currentPassword: "old-secret",
        newPassword: "new-secret-123",
      );

      expect(result.isOk, isTrue);
      final req = adapter.requests.single;
      expect(req.method, "POST");
      expect(req.path, "/api/users/me/password");
      expect(req.data, {
        "current_password": "old-secret",
        "new_password": "new-secret-123",
      });
      expect(req.headers["Authorization"], "Bearer jwt-1");
    });

    test("uploadAvatar POSTs a multipart 'avatar' file and parses the user",
        () async {
      final adapter =
          _CapturingAdapter((_) => _envelope(_userJson(photo: "/uploads/x.png")));
      final repo = UserRepo(_wired(adapter));

      final result = await repo.uploadAvatar(
        bytes: _png,
        filename: "me.png",
        mimeType: "image/png",
      );

      expect(result.isOk, isTrue);
      expect(result.data!.photo, "/uploads/x.png");
      final req = adapter.requests.single;
      expect(req.method, "POST");
      expect(req.path, "/api/users/me/avatar");
      expect(req.headers["Authorization"], "Bearer jwt-1");
      final form = req.data as FormData;
      expect(form.files.single.key, "avatar");
      expect(form.files.single.value.filename, "me.png");
      expect(form.files.single.value.length, _png.length);
    });

    test("server error codes come back mapped through the friendly table",
        () async {
      final adapter =
          _CapturingAdapter((_) => _errEnvelope("VALIDATION_ERROR", "boom"));
      final repo = UserRepo(_wired(adapter));

      final result = await repo.patchMe(name: "A", phone: "+85512345678");

      expect(result.isOk, isFalse);
      expect(result.code, "VALIDATION_ERROR");
      expect(result.message, apiErrorMessages["VALIDATION_ERROR"]);
    });
  });

  group("session identity carries phone + photo", () {
    test("AuthSession picks phone/photo up from the login payload", () {
      final session = AuthSession.fromJson({
        "token": "jwt",
        "user": _userJson(photo: "/uploads/a.png"),
      });
      expect(session.phone, "+85512999999");
      expect(session.photo, "/uploads/a.png");
      expect(session.state.photo, "/uploads/a.png");
    });

    test("TokenStore persists phone/photo across restarts", () async {
      SharedPreferences.setMockInitialValues({});
      await TokenStore().save(const AuthState(
        token: "jwt",
        role: "driver",
        name: "Dara Sok",
        email: "dara@taxi.demo",
        phone: "+85512999999",
        photo: "/uploads/a.png",
      ));

      final loaded = await TokenStore().load();
      expect(loaded?.phone, "+85512999999");
      expect(loaded?.photo, "/uploads/a.png");

      await TokenStore().clear();
      expect(await TokenStore().load(), isNull);
    });

    test("adoptUser reconciles the session with server truth and persists it",
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith(() => _SpyAuth(_session()))],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);

      await container
          .read(authProvider.notifier)
          .adoptUser(_userModel(photo: "/uploads/b.png"));

      final state = container.read(authProvider).valueOrNull!;
      expect(state.photo, "/uploads/b.png");
      expect(state.token, "jwt"); // untouched
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString("auth.photo"), "/uploads/b.png");
    });

    test("updateProfile optimistically applies and adopts server truth",
        () async {
      SharedPreferences.setMockInitialValues({});
      final repo = _StubUserRepo();
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(() => _SpyAuth(_session())),
        userRepoProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      await container.read(authProvider.future);

      final error = await container.read(authProvider.notifier).updateProfile(
            name: "Dara Two",
            phone: "+85512345678",
          );

      expect(error, isNull);
      expect(repo.patchCalls.single.name, "Dara Two");
      expect(repo.patchCalls.single.phone, "+85512345678");
      final state = container.read(authProvider).valueOrNull!;
      expect(state.name, "Dara Two");
      expect(state.phone, "+85512345678");
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString("auth.name"), "Dara Two");
    });

    test("updateProfile reverts the optimistic write when the PATCH fails",
        () async {
      SharedPreferences.setMockInitialValues({});
      final repo = _StubUserRepo()
        ..patchResult = const ApiResult.err(
            "VALIDATION_ERROR", "Please check your details and try again.");
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(() => _SpyAuth(_session())),
        userRepoProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      await container.read(authProvider.future);

      final error = await container.read(authProvider.notifier).updateProfile(
            name: "Bad Name",
            phone: "+85512345678",
          );

      expect(error, "Please check your details and try again.");
      final state = container.read(authProvider).valueOrNull!;
      expect(state.name, "Dara Sok"); // reverted
      expect(state.phone, "+85512999999");
    });
  });

  group("Account tab", () {
    testWidgets("renders name, email, role chip and the initials avatar "
        "when no photo is set", (tester) async {
      await _pump(tester, session: _session());

      expect(find.text("Account"), findsOneWidget);
      expect(find.text("Dara Sok"), findsOneWidget);
      expect(find.text("dara@taxi.demo"), findsOneWidget);
      expect(find.text("CUSTOMER"), findsOneWidget);
      expect(find.text("DS"), findsOneWidget);
      expect(find.text("Log out"), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage),
        findsNothing,
      );
    });

    testWidgets("uses the server photo URL when the session has one",
        (tester) async {
      await _pump(tester, session: _session(photo: "/uploads/me.png"));
      await tester.pump();

      final images = tester
          .widgetList<Image>(find.byWidgetPredicate((w) => w is Image))
          .where((img) => img.image is NetworkImage)
          .toList();
      expect(images, hasLength(1));
      expect((images.single.image as NetworkImage).url,
          "$apiBaseUrl/uploads/me.png");
    });

    testWidgets("tapping the avatar picks from the gallery and uploads it, "
        "then adopts the server truth", (tester) async {
      final userRepo = _StubUserRepo();
      var pickCalls = 0;
      final container = await _pump(
        tester,
        session: _session(),
        userRepo: userRepo,
        picker: () async {
          pickCalls++;
          // fromData ignores `name` off-web — carry it via `path`.
          return XFile.fromData(_png, path: "me.png", mimeType: "image/png");
        },
      );

      await tester.tap(find.byKey(const Key("account-avatar")));
      await tester.pumpAndSettle();

      expect(pickCalls, 1);
      expect(userRepo.uploadBytes.single, _png);
      expect(userRepo.uploadNames.single, "me.png");
      expect(userRepo.uploadMimes.single, "image/png");
      expect(
        container.read(authProvider).valueOrNull!.photo,
        "/uploads/fresh.png",
      );
    });

    testWidgets("dismissing the gallery picker uploads nothing",
        (tester) async {
      final userRepo = _StubUserRepo();
      await _pump(
        tester,
        session: _session(),
        userRepo: userRepo,
        picker: () async => null,
      );

      await tester.tap(find.byKey(const Key("account-avatar")));
      await tester.pumpAndSettle();

      expect(userRepo.uploadBytes, isEmpty);
      expect(find.text("DS"), findsOneWidget);
    });

    testWidgets("the edit sheet patches name + phone and shows server truth",
        (tester) async {
      final userRepo = _StubUserRepo()
        ..patchResult = ApiResult.ok(const User(
          id: 9,
          role: "customer",
          name: "Dara Two",
          phone: "+85512345678",
          email: "dara@taxi.demo",
          rating: 5,
          active: true,
        ));
      final container = await _pump(
        tester,
        session: _session(),
        userRepo: userRepo,
      );

      await tester.tap(find.byTooltip("Edit profile"));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), "Dara Two");
      await tester.enterText(find.byType(TextFormField).at(1), "+85512345678");
      await tester.tap(find.text("Save changes"));
      await tester.pumpAndSettle();

      expect(userRepo.patchCalls.single.name, "Dara Two");
      expect(userRepo.patchCalls.single.phone, "+85512345678");
      expect(find.text("Dara Two"), findsOneWidget); // card reflects truth
      expect(container.read(authProvider).valueOrNull!.phone, "+85512345678");
      expect(find.text("Save changes"), findsNothing); // sheet closed
    });

    testWidgets("a rejected profile PATCH surfaces the mapped error inline "
        "and reverts the optimistic name", (tester) async {
      final userRepo = _StubUserRepo()
        ..patchResult = const ApiResult.err(
            "VALIDATION_ERROR", "Please check your details and try again.");
      await _pump(tester, session: _session(), userRepo: userRepo);

      await tester.tap(find.byTooltip("Edit profile"));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), "Bad Name");
      await tester.enterText(find.byType(TextFormField).at(1), "+85512345678");
      await tester.tap(find.text("Save changes"));
      await tester.pumpAndSettle();

      expect(find.text("Please check your details and try again."),
          findsOneWidget);
      expect(find.text("Save changes"), findsOneWidget); // sheet stayed open
      expect(find.text("Dara Sok"), findsOneWidget); // optimistic reverted
    });

    testWidgets("password sheet blocks a confirm mismatch locally",
        (tester) async {
      final userRepo = _StubUserRepo();
      await _pump(tester, session: _session(), userRepo: userRepo);

      await tester.tap(find.text("Change password"));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), "oldsecret1");
      await tester.enterText(find.byType(TextFormField).at(1), "newsecret1");
      await tester.enterText(find.byType(TextFormField).at(2), "different1");
      await tester.tap(find.text("Update password"));
      await tester.pump();

      expect(find.text("Passwords don't match"), findsOneWidget);
      expect(userRepo.passwordCalls, isEmpty);
    });

    testWidgets("a successful password change clears the session, lands on "
        "/login and shows the re-login notice", (tester) async {
      final userRepo = _StubUserRepo();
      final container = await _pump(
        tester,
        session: _session(),
        userRepo: userRepo,
        fullRouter: true,
      );

      await tester.tap(find.descendant(
          of: find.byType(NavigationBar), matching: find.text("Account")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Change password"));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), "oldsecret1");
      await tester.enterText(find.byType(TextFormField).at(1), "newsecret1234");
      await tester.enterText(find.byType(TextFormField).at(2), "newsecret1234");
      await tester.tap(find.text("Update password"));
      await tester.pumpAndSettle();

      expect(userRepo.passwordCalls.single.current, "oldsecret1");
      expect(userRepo.passwordCalls.single.next, "newsecret1234");
      expect((container.read(authProvider.notifier) as _SpyAuth).logoutCalls, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.textContaining("log in again"), findsWidgets);
    });

    testWidgets("a wrong current password keeps the sheet open with a clear "
        "message", (tester) async {
      final userRepo = _StubUserRepo()
        ..passwordResult =
            const ApiResult.err("UNAUTHORIZED", "Please log in again.");
      final container = await _pump(
        tester,
        session: _session(),
        userRepo: userRepo,
      );
      final spy = container.read(authProvider.notifier) as _SpyAuth;

      await tester.tap(find.text("Change password"));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), "wrongpass1");
      await tester.enterText(find.byType(TextFormField).at(1), "newsecret1234");
      await tester.enterText(find.byType(TextFormField).at(2), "newsecret1234");
      await tester.tap(find.text("Update password"));
      await tester.pumpAndSettle();

      expect(find.text("Your current password is incorrect."), findsOneWidget);
      expect(find.text("Update password"), findsOneWidget); // sheet stayed open
      expect(spy.logoutCalls, 0); // session kept
    });

    testWidgets("a short new password is blocked before any request",
        (tester) async {
      final userRepo = _StubUserRepo();
      await _pump(tester, session: _session(), userRepo: userRepo);

      await tester.tap(find.text("Change password"));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), "oldsecret1");
      await tester.enterText(find.byType(TextFormField).at(1), "short");
      await tester.enterText(find.byType(TextFormField).at(2), "short");
      await tester.tap(find.text("Update password"));
      await tester.pump();

      expect(find.text("At least 8 characters"), findsOneWidget);
      expect(userRepo.passwordCalls, isEmpty);
    });

    testWidgets("drivers see their vehicle block, customers do not",
        (tester) async {
      final driverRepo = _StubDriverRepo(meResult: ApiResult.ok(_vehicle));
      await _pump(
        tester,
        session: _session(role: "driver"),
        driverRepo: driverRepo,
      );

      expect(find.text("Vehicle"), findsOneWidget);
      expect(find.text("Honda Dream 2020"), findsOneWidget);
      expect(find.text("PP-1A-2345"), findsOneWidget);
      expect(find.text("KH-DL-1111"), findsOneWidget);
      expect(find.textContaining(r"$1.25"), findsOneWidget);

      await _pump(tester, session: _session(role: "customer"));
      expect(find.text("Vehicle"), findsNothing);
    });

    testWidgets("vehicle edit goes through driver updateProfile and renders "
        "the server truth", (tester) async {
      final driverRepo = _StubDriverRepo(meResult: ApiResult.ok(_vehicle));
      await _pump(
        tester,
        session: _session(role: "driver"),
        driverRepo: driverRepo,
      );

      await tester.tap(find.byTooltip("Edit vehicle"));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), "PP-9Z-9999");
      await tester.enterText(find.byType(TextFormField).at(3), "1.30");
      await tester.tap(find.text("Update vehicle"));
      await tester.pumpAndSettle();

      expect(driverRepo.updateCalls.single["car_model"], "Honda Dream 2020");
      expect(driverRepo.updateCalls.single["plate"], "PP-9Z-9999");
      expect(driverRepo.updateCalls.single["license_no"], "KH-DL-1111");
      expect(driverRepo.updateCalls.single["price_per_km"], closeTo(1.30, 1e-9));
      expect(find.text("PP-9Z-9999"), findsOneWidget); // refreshed rows
    });

    testWidgets("an unparsable price is blocked locally", (tester) async {
      final driverRepo = _StubDriverRepo(meResult: ApiResult.ok(_vehicle));
      await _pump(
        tester,
        session: _session(role: "driver"),
        driverRepo: driverRepo,
      );

      await tester.tap(find.byTooltip("Edit vehicle"));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(3), "abc");
      await tester.tap(find.text("Update vehicle"));
      await tester.pump();

      expect(find.text("Enter a valid price per km"), findsOneWidget);
      expect(driverRepo.updateCalls, isEmpty);
    });

    testWidgets("a driver without a vehicle profile degrades to a hint",
        (tester) async {
      final driverRepo = _StubDriverRepo()
        ..meResult = const ApiResult.err("NOT_FOUND", "none");
      await _pump(
        tester,
        session: _session(role: "driver"),
        driverRepo: driverRepo,
      );

      expect(find.text("No vehicle yet"), findsOneWidget);
      expect(find.byTooltip("Edit vehicle"), findsNothing);
    });

    testWidgets("vehicle photo grid renders a tile per gallery photo plus "
        "the add tile", (tester) async {
      final driverRepo =
          _StubDriverRepo(meResult: ApiResult.ok(_vehicleWithGallery));
      await _pump(
        tester,
        session: _session(role: "driver"),
        driverRepo: driverRepo,
      );

      expect(find.byKey(const Key("vehicle-photo-grid")), findsOneWidget);
      expect(find.byKey(const Key("vehicle-photo-tile-0")), findsOneWidget);
      expect(find.byKey(const Key("vehicle-photo-tile-1")), findsOneWidget);
      expect(find.byKey(const Key("vehicle-photo-remove-0")), findsOneWidget);
      expect(find.byKey(const Key("vehicle-photo-remove-1")), findsOneWidget);
      expect(find.byKey(const Key("vehicle-add-photos")), findsOneWidget);
    });

    testWidgets("a legacy cover-only vehicle still shows one grid tile",
        (tester) async {
      final driverRepo =
          _StubDriverRepo(meResult: ApiResult.ok(_vehicleWithPhoto));
      await _pump(
        tester,
        session: _session(role: "driver"),
        driverRepo: driverRepo,
      );

      expect(find.byKey(const Key("vehicle-photo-tile-0")), findsOneWidget);
      expect(find.byKey(const Key("vehicle-photo-tile-1")), findsNothing);
    });

    testWidgets("the add tile picks multiple photos, uploads them through "
        "the repo and adopts the server-truth gallery", (tester) async {
      final driverRepo = _StubDriverRepo(meResult: ApiResult.ok(_vehicle));
      await _pump(
        tester,
        session: _session(role: "driver"),
        driverRepo: driverRepo,
        multiPicker: () async => [
          XFile.fromData(_png, path: "bike.png", mimeType: "image/png"),
          XFile.fromData(_png, path: "ride.jpg", mimeType: "image/jpeg"),
        ],
      );

      await tester.tap(find.byKey(const Key("vehicle-add-photos")));
      await tester.pumpAndSettle();

      expect(driverRepo.photosUploadCalls.single, hasLength(2));
      // Server truth adopted: both photos render as tiles.
      expect(find.byKey(const Key("vehicle-photo-tile-0")), findsOneWidget);
      expect(find.byKey(const Key("vehicle-photo-tile-1")), findsOneWidget);
    });

    testWidgets("tapping a tile's X removes that index through the repo",
        (tester) async {
      final driverRepo =
          _StubDriverRepo(meResult: ApiResult.ok(_vehicleWithGallery));
      await _pump(
        tester,
        session: _session(role: "driver"),
        driverRepo: driverRepo,
      );

      await tester.tap(find.byKey(const Key("vehicle-photo-remove-1")));
      await tester.pumpAndSettle();

      expect(driverRepo.removeCalls.single, 1);
      // Server truth adopted: one tile left, re-indexed.
      expect(find.byKey(const Key("vehicle-photo-tile-0")), findsOneWidget);
      expect(find.byKey(const Key("vehicle-photo-tile-1")), findsNothing);
    });

    testWidgets("a failed upload surfaces the mapped error without adopting "
        "anything", (tester) async {
      final driverRepo = _StubDriverRepo(meResult: ApiResult.ok(_vehicle))
        ..photosUploadResult = const ApiResult.err(
          "VALIDATION_ERROR",
          "Up to 6 vehicle photos are allowed",
        );
      await _pump(
        tester,
        session: _session(role: "driver"),
        driverRepo: driverRepo,
        multiPicker: () async => [
          XFile.fromData(_png, path: "bike.png", mimeType: "image/png"),
        ],
      );

      await tester.tap(find.byKey(const Key("vehicle-add-photos")));
      await tester.pumpAndSettle();

      expect(
        find.text("Up to 6 vehicle photos are allowed"),
        findsOneWidget, // SnackBar
      );
      expect(driverRepo.photosUploadCalls.single, hasLength(1));
      // No tiles without server truth.
      expect(find.byKey(const Key("vehicle-photo-tile-0")), findsNothing);
    });

    testWidgets("a failed removal surfaces the error and keeps the grid",
        (tester) async {
      final driverRepo =
          _StubDriverRepo(meResult: ApiResult.ok(_vehicleWithGallery))
            ..removeResult = const ApiResult.err(
              "VALIDATION_ERROR",
              "Photo index out of range",
            );
      await _pump(
        tester,
        session: _session(role: "driver"),
        driverRepo: driverRepo,
      );

      await tester.tap(find.byKey(const Key("vehicle-photo-remove-0")));
      await tester.pumpAndSettle();

      expect(find.text("Photo index out of range"), findsOneWidget);
      expect(find.byKey(const Key("vehicle-photo-tile-0")), findsOneWidget);
      expect(find.byKey(const Key("vehicle-photo-tile-1")), findsOneWidget);
    });
  });
}
