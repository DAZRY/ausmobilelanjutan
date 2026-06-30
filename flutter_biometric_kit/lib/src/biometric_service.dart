import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

import 'biometric_exception.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Cek apakah device mendukung dan memiliki sensor biometrik.
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on LocalAuthException catch (e) {
      debugPrint('[BiometricService] isBiometricAvailable error: $e');
      return false;
    }
  }

  /// Mengembalikan daftar jenis biometrik yang terdaftar di perangkat.
  ///
  /// Android: [BiometricType.weak] = face 2D, [BiometricType.strong] = fingerprint/iris
  /// iOS:     [BiometricType.face] = Face ID, [BiometricType.fingerprint] = Touch ID
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on LocalAuthException catch (e) {
      debugPrint('[BiometricService] getAvailableBiometrics error: $e');
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
      final bool result = await _auth.authenticate(
        localizedReason: reason,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Verifikasi Diperlukan',
            cancelButton: 'Batal',
            signInHint: 'Tempelkan jari atau arahkan wajah',
          ),
        ],
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );

      if (!result) {
        throw BiometricException(
          code: BiometricErrorCode.userCanceled,
          message: 'User membatalkan autentikasi',
          userMessage: 'Autentikasi dibatalkan.',
        );
      }

      return true;
    } on LocalAuthException catch (e) {
      throw BiometricException.fromLocalAuthException(e);
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
    await _auth.stopAuthentication();
  }
}
