import 'package:flutter/services.dart';

import 'biometric_exception.dart';

/// Tipe biometrik yang didukung.
enum BiometricType { fingerprint, face, iris, weak, strong, unknown }

/// Layanan autentikasi biometrik berbasis MethodChannel.
///
/// Tidak bergantung pada package `local_auth` — menggunakan channel
/// native langsung sehingga bisa dipakai sebagai library mandiri.
class BiometricService {
  static const MethodChannel _channel =
      MethodChannel('flutter_biometric_kit/auth');

  /// Cek apakah device mendukung dan memiliki sensor biometrik.
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canCheck =
          await _channel.invokeMethod<bool>('canCheckBiometrics') ?? false;
      final bool isSupported =
          await _channel.invokeMethod<bool>('isDeviceSupported') ?? false;
      return canCheck && isSupported;
    } on PlatformException catch (e) {
      print('[BiometricService] isBiometricAvailable error: $e');
      return false;
    }
  }

  /// Mengembalikan daftar jenis biometrik yang terdaftar di perangkat.
  ///
  /// Android: `weak` = face 2D, `strong` = fingerprint/iris
  /// iOS:     `face` = Face ID, `fingerprint` = Touch ID
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final List<dynamic>? types =
          await _channel.invokeMethod<List<dynamic>>('getAvailableBiometrics');
      if (types == null) return [];
      return types.map((e) => _parseBiometricType(e as String)).toList();
    } on PlatformException catch (e) {
      print('[BiometricService] getAvailableBiometrics error: $e');
      return [];
    }
  }

  /// Memulai alur autentikasi biometrik.
  ///
  /// [reason] adalah teks yang ditampilkan di dialog OS.
  /// Melempar [BiometricException] jika gagal — tidak pernah melempar tipe lain.
  Future<bool> authenticate({
    String reason = 'Verifikasi identitas Anda untuk melanjutkan',
  }) async {
    final bool available = await isBiometricAvailable();
    if (!available) {
      throw BiometricException(
        code: BiometricErrorCode.noBiometricHardware,
        message: 'Device tidak support biometrik',
        userMessage: 'Perangkat Anda tidak memiliki sensor biometrik.',
      );
    }

    final List<BiometricType> types = await getAvailableBiometrics();
    if (types.isEmpty) {
      throw BiometricException(
        code: BiometricErrorCode.notEnrolled,
        message: 'Tidak ada biometrik terdaftar',
        userMessage:
            'Belum ada sidik jari atau wajah tersimpan. '
            'Silakan daftarkan di Pengaturan > Keamanan.',
      );
    }

    try {
      final Map<String, dynamic> args = <String, dynamic>{
        'reason': reason,
        'biometricOnly': false,
        'sensitiveTransaction': true,
        'persistAcrossBackgrounding': true,
        'androidTitle': 'Verifikasi Diperlukan',
        'androidCancelButton': 'Batal',
        'androidSignInHint': 'Tempelkan jari atau arahkan wajah',
      };

      final bool result =
          await _channel.invokeMethod<bool>('authenticate', args) ?? false;

      if (!result) {
        throw BiometricException(
          code: BiometricErrorCode.userCanceled,
          message: 'User membatalkan autentikasi',
          userMessage: 'Autentikasi dibatalkan.',
        );
      }

      return true;
    } on PlatformException catch (e) {
      throw BiometricException.fromPlatform(
        e.code,
        e.message,
      );
    } on BiometricException {
      rethrow;
    } catch (e) {
      throw BiometricException(
        code: BiometricErrorCode.unknown,
        message: 'Error tidak diketahui: $e',
        userMessage: 'Terjadi kesalahan. Silakan coba lagi.',
      );
    }
  }

  /// Menghentikan autentikasi yang sedang berjalan (Android only).
  Future<void> stopAuthentication() async {
    await _channel.invokeMethod<void>('stopAuthentication');
  }

  BiometricType _parseBiometricType(String value) {
    switch (value) {
      case 'fingerprint':
        return BiometricType.fingerprint;
      case 'face':
        return BiometricType.face;
      case 'iris':
        return BiometricType.iris;
      case 'weak':
        return BiometricType.weak;
      case 'strong':
        return BiometricType.strong;
      default:
        return BiometricType.unknown;
    }
  }
}
