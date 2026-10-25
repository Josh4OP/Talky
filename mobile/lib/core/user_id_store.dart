import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Identidad declarada del MVP: un identificador anónimo generado en el
/// dispositivo. No es autenticación y se explica así en la pantalla de perfil.
class UserIdStore {
  static const storageKey = 'talky.user_id';
  static final _validId = RegExp(r'^[A-Za-z0-9_.@-]{1,64}$');

  Future<String> getOrCreate(SharedPreferences prefs) async {
    final stored = prefs.getString(storageKey);
    if (stored != null && _validId.hasMatch(stored)) return stored;

    final id = 'talky-${const Uuid().v4().replaceAll('-', '')}';
    await prefs.setString(storageKey, id);
    return id;
  }
}
