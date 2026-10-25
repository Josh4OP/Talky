import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_id_store.dart';

/// Preferencias locales de la aplicación. El historial vive en el servidor;
/// aquí solo se guarda el identificador, la bienvenida y ajustes de interfaz.
class PreferencesController extends ChangeNotifier {
  PreferencesController({UserIdStore? userIdStore})
      : _userIdStore = userIdStore ?? UserIdStore();

  static const onboardingKey = 'talky.onboarding_complete';
  static const reduceMotionKey = 'talky.reduce_motion';
  static const demoModeKey = 'talky.demo_mode';

  final UserIdStore _userIdStore;

  SharedPreferences? _prefs;
  bool _ready = false;
  String _userId = '';
  bool _onboardingComplete = false;
  bool _reduceMotion = false;
  bool _demoMode = false;

  bool get ready => _ready;
  String get userId => _userId;
  bool get onboardingComplete => _onboardingComplete;
  bool get reduceMotion => _reduceMotion;
  bool get demoMode => _demoMode;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _userId = await _userIdStore.getOrCreate(_prefs!);
    _onboardingComplete = _prefs!.getBool(onboardingKey) ?? false;
    _reduceMotion = _prefs!.getBool(reduceMotionKey) ?? false;
    _demoMode = _prefs!.getBool(demoModeKey) ?? false;
    _ready = true;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    if (_onboardingComplete) return;
    _onboardingComplete = true;
    notifyListeners();
    await _prefs?.setBool(onboardingKey, true);
  }

  Future<void> resetOnboarding() async {
    _onboardingComplete = false;
    notifyListeners();
    await _prefs?.setBool(onboardingKey, false);
  }

  Future<void> setReduceMotion(bool value) async {
    if (_reduceMotion == value) return;
    _reduceMotion = value;
    notifyListeners();
    await _prefs?.setBool(reduceMotionKey, value);
  }

  Future<void> setDemoMode(bool value) async {
    if (_demoMode == value) return;
    _demoMode = value;
    notifyListeners();
    await _prefs?.setBool(demoModeKey, value);
  }
}
