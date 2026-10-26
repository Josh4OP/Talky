import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dónde se guardan las preferencias; en pruebas se usa una en memoria.
abstract class PreferencesStorage {
  Future<bool?> readBool(String key);
  Future<void> writeBool(String key, bool value);
}

class SharedPreferencesStorage implements PreferencesStorage {
  @override
  Future<bool?> readBool(String key) async => (await SharedPreferences.getInstance()).getBool(key);

  @override
  Future<void> writeBool(String key, bool value) async => (await SharedPreferences.getInstance()).setBool(key, value);
}

/// Preferencias locales: bienvenida vista, modo de ejemplo y movimiento reducido.
/// El historial vive en el servidor; aquí no se guarda nada de los análisis.
class PreferencesController extends ChangeNotifier {
  PreferencesController({required PreferencesStorage storage}) : _storage = storage;

  static const _welcomeKey = 'talky.welcome_seen';
  static const _demoKey = 'talky.demo_mode';
  static const _motionKey = 'talky.reduce_motion';

  final PreferencesStorage _storage;

  bool welcomeSeen = false;
  bool demoMode = false;

  /// Menos movimiento en la mascota y las transiciones, además de lo que pida el sistema.
  bool reduceMotion = false;

  Future<void> load() async {
    welcomeSeen = await _storage.readBool(_welcomeKey) ?? false;
    demoMode = await _storage.readBool(_demoKey) ?? false;
    reduceMotion = await _storage.readBool(_motionKey) ?? false;
    notifyListeners();
  }

  Future<void> setWelcomeSeen(bool value) async {
    welcomeSeen = value;
    notifyListeners();
    await _storage.writeBool(_welcomeKey, value);
  }

  Future<void> setReduceMotion(bool value) async {
    reduceMotion = value;
    notifyListeners();
    await _storage.writeBool(_motionKey, value);
  }

  Future<void> setDemoMode(bool value) async {
    demoMode = value;
    notifyListeners();
    await _storage.writeBool(_demoKey, value);
  }
}
