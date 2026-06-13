// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

String? readToken(String key) => html.window.localStorage[key];

void saveToken(String key, String value) {
  html.window.localStorage[key] = value;
}

void clearToken(String key) {
  html.window.localStorage.remove(key);
}
