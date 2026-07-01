enum BiometricErrorCode {
  noBiometricHardware,
  notEnrolled,
  temporaryLockout,
  biometricLockout,
  userCanceled,
  systemCanceled,
  unknown,
}

class BiometricException implements Exception {
  final BiometricErrorCode code;
  final String message;
  final String userMessage;

  const BiometricException({
    required this.code,
    required this.message,
    required this.userMessage,
  });

  /// Konstruksi dari platform error code yang dikembalikan MethodChannel.
  factory BiometricException.fromPlatform(String errorCode, String? description) {
    final String desc = description ?? '-';

    switch (errorCode) {
      case 'noBiometricHardware':
        return BiometricException(
          code: BiometricErrorCode.noBiometricHardware,
          message: 'noBiometricHardware: $desc',
          userMessage: 'Perangkat tidak memiliki sensor biometrik.',
        );
      case 'noBiometricsEnrolled':
        return BiometricException(
          code: BiometricErrorCode.notEnrolled,
          message: 'biometricNotEnrolled: $desc',
          userMessage:
              'Belum ada sidik jari atau wajah tersimpan. '
              'Silakan daftarkan di Pengaturan > Keamanan.',
        );
      case 'temporaryLockout':
        return BiometricException(
          code: BiometricErrorCode.temporaryLockout,
          message: 'temporaryLockout: $desc',
          userMessage: 'Terlalu banyak percobaan gagal. Tunggu lalu coba lagi.',
        );
      case 'biometricLockout':
        return BiometricException(
          code: BiometricErrorCode.biometricLockout,
          message: 'biometricLockout: $desc',
          userMessage:
              'Biometrik dikunci. Buka kunci perangkat dengan PIN dulu.',
        );
      case 'userCanceled':
        return BiometricException(
          code: BiometricErrorCode.userCanceled,
          message: 'userCanceled: $desc',
          userMessage: 'Autentikasi dibatalkan.',
        );
      case 'systemCanceled':
        return BiometricException(
          code: BiometricErrorCode.systemCanceled,
          message: 'systemCanceled: $desc',
          userMessage: 'Autentikasi dibatalkan oleh sistem.',
        );
      default:
        return BiometricException(
          code: BiometricErrorCode.unknown,
          message: 'unknown [$errorCode]: $desc',
          userMessage: 'Terjadi kesalahan tidak terduga. Silakan coba lagi.',
        );
    }
  }

  /// Tampilkan tombol "Coba lagi"
  bool get isRetryable =>
      code == BiometricErrorCode.userCanceled ||
      code == BiometricErrorCode.systemCanceled ||
      code == BiometricErrorCode.unknown;

  /// Tampilkan tombol "Buka Pengaturan" untuk mendaftarkan biometrik
  bool get requiresSettings => code == BiometricErrorCode.notEnrolled;

  /// Otomatis fallback ke password — tidak ada hardware atau locked permanen
  bool get requiresFallback =>
      code == BiometricErrorCode.noBiometricHardware ||
      code == BiometricErrorCode.biometricLockout;

  @override
  String toString() => 'BiometricException($code): $message';
}
