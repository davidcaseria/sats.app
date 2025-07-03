import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart' hide Token;
import 'package:api_client/api_client.dart' hide PaymentRequest;
import 'package:built_collection/built_collection.dart';
import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:sats_app/config.dart';
import 'package:sats_app/storage.dart';
import 'package:uuid/uuid.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  late DefaultApi _apiClient;

  factory ApiService() {
    return _instance;
  }

  ApiService._internal() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: Duration(seconds: 10),
        receiveTimeout: Duration(seconds: 10),
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final cognitoPlugin = Amplify.Auth.getPlugin(AmplifyAuthCognito.pluginKey);
          final session = await cognitoPlugin.fetchAuthSession();
          final jwt = session.userPoolTokensResult.value.accessToken.raw;
          options.headers['Authorization'] = 'Bearer $jwt';
          return handler.next(options);
        },
      ),
    );

    _apiClient = DefaultApi(dio, standardSerializers);
  }

  DefaultApi get client => _apiClient;

  Future<Uri> createPayLink({required Token token}) async {
    final id = Uuid().v4();
    final idBytes = Uuid.parse(id);

    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 10000, bits: 128);
    final password = SecretKeyData.random(length: 8);
    final tokenSecret = await pbkdf2.deriveKey(secretKey: password, nonce: idBytes);

    await _sendToken(token: token, tokenSecret: tokenSecret, id: id);

    final urlId = base64UrlEncode(idBytes).replaceAll('=', '');
    final urlPassword = base64UrlEncode(password.bytes).replaceAll('=', '');
    final uri = Uri.parse('${AppConfig.linkBaseUrl}/t/$urlId#$urlPassword');
    return uri;
  }

  Future<Uri> createRequestLink({required PaymentRequest request}) async {
    final res = await _sendRequest(request: request);
    final idBytes = Uuid.parse(res.id);
    final urlId = base64UrlEncode(idBytes).replaceAll('=', '');
    final uri = Uri.parse('${AppConfig.linkBaseUrl}/r/$urlId');
    return uri;
  }

  Future<void> deletePaymentRequest({required String id}) async {
    try {
      await _apiClient.deletePaymentRequest(id: id);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        safePrint('Payment request with id $id not found, it may have already been deleted.');
      } else {
        rethrow;
      }
    }
  }

  Future<UserResponse> getUserProfile() async {
    final userId = await _userId();
    final response = await _apiClient.getUser(id: userId);
    return response.data!;
  }

  Future<List<PaymentRequestResponse>> listAllPaymentRequests() async {
    final response = await _apiClient.listPaymentRequests(f: UserPayFilter.all);
    return response.data!.toList();
  }

  Future<List<UserResponse>> searchUsers({required String query}) async {
    final response = await _apiClient.searchUsers(s: query);
    return response.data!.toList();
  }

  Future<void> sendRequestToUser({required PaymentRequest request, required String payerUserId}) async {
    await _sendRequest(request: request, payerUserId: payerUserId);
  }

  Future<void> sendTokenToUser({required Token token, required String payeeUserId, required String payeePubKey}) async {
    final seed = await AppStorage().getSeed();
    final sharedSecretHex = deriveSharedSecret(secret: seed!, pubKey: payeePubKey);
    final tokenSecret = SecretKeyData(keyHexToBytes(key: sharedSecretHex));
    await _sendToken(token: token, tokenSecret: tokenSecret, payeeUserId: payeeUserId);
  }

  Future<PaymentRequestResponse> _sendRequest({required PaymentRequest request, String? payerUserId}) async {
    final req = PaymentRequestBuilder()
      ..encoded = request.encode()
      ..payerUserId = payerUserId;
    final response = await _apiClient.createPaymentRequest(paymentRequest: req.build());
    return response.data!;
  }

  Future<void> updateProfile({required bool isPublic}) async {
    final userId = await _userId();
    final request = UserUpdateRequestBuilder()..isPublic = isPublic;
    await _apiClient.updateUser(id: userId, userUpdateRequest: request.build());
  }

  Future<void> uploadProfilePicture({required List<int> imageBytes}) async {
    final userId = await _userId();
    final request = UploadProfilePictureRequestBuilder()..bytes = ListBuilder<int>(imageBytes);
    await _apiClient.uploadProfilePicture(id: userId, uploadProfilePictureRequest: request.build());
  }

  Future<void> _sendToken({
    required Token token,
    required SecretKey tokenSecret,
    String? id,
    String? payeeUserId,
  }) async {
    final tokenId = id ?? Uuid().v4();

    final algorithm = AesGcm.with128bits();
    final nonce = algorithm.newNonce();
    final secretBox = await algorithm.encrypt(token.raw!.toList(), secretKey: tokenSecret, nonce: nonce);

    // Concatenate nonce + cipherText + mac for encoding
    final encryptedToken = base64Encode(nonce + secretBox.cipherText + secretBox.mac.bytes);

    final tokenRequest = TokenRequestBuilder()
      ..encryptedToken = encryptedToken
      ..payeeUserId = payeeUserId;
    await _apiClient.storeToken(id: tokenId, tokenRequest: tokenRequest.build());
  }

  Future<String> _userId() async {
    final user = await Amplify.Auth.getCurrentUser();
    if (user.userId.isEmpty) {
      throw Exception('User ID is empty, cannot perform operation');
    }
    return user.userId;
  }
}
