import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart' hide Token;
import 'package:api_client/api_client.dart';
import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:sats_app/config.dart';
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

  Future<Uri> createPayLink({required Token token, String? payeeUserId}) async {
    final id = Uuid().v4();
    final idBytes = Uuid.parse(id);

    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 10000, bits: 128);
    final password = SecretKeyData.random(length: 8);
    final tokenSecret = await pbkdf2.deriveKey(secretKey: password, nonce: idBytes);

    final algorithm = AesGcm.with128bits();
    final nonce = algorithm.newNonce();
    final secretBox = await algorithm.encrypt(token.raw!.toList(), secretKey: tokenSecret, nonce: nonce);
    final encryptedToken = base64Encode(nonce + secretBox.cipherText);
    safePrint('Encrypted Token: $encryptedToken');

    final tokenRequest = TokenRequestBuilder()
      ..encryptedToken = encryptedToken
      ..payeeUserId = payeeUserId;
    await _apiClient.storeToken(id: id, tokenRequest: tokenRequest.build());
    final urlId = base64UrlEncode(idBytes).replaceAll('=', '');
    final urlPassword = base64UrlEncode(password.bytes).replaceAll('=', '');
    final uri = Uri.parse('${AppConfig.payLinkBaseUrl}/t/$urlId#$urlPassword');
    return uri;
  }
}
