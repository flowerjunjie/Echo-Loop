/// Web platform stub - replaces package:web on non-web platforms (VM/test).
library;
import 'dart:typed_data';

// ── Storage stubs ─────────────────────────────────────────────────────────────
class _StubLocalStorage {
  String? getItem(String key) => null;
  void setItem(String key, String value) {}
  void removeItem(String key) {}
  void clear() {}
}

class _StubSessionStorage {
  String? getItem(String key) => null;
  void setItem(String key, String value) {}
  void removeItem(String key) {}
  void clear() {}
}

// ── Web API stubs ─────────────────────────────────────────────────────────────
class _StubNavigator {
  _StubMediaDevices get mediaDevices => _theMediaDevices;
}
final _theNavigator = _StubNavigator();

class _StubMediaDevices {
  Future<_StubMediaStream> getUserMedia(dynamic constraints) async => _theMediaStream;
}
final _theMediaDevices = _StubMediaDevices();

class _StubMediaStream {}
final _theMediaStream = _StubMediaStream();

class _StubMediaRecorder {
  _StubMediaRecorder([dynamic stream]);
  void start([int? timeslice]) {}
  void stop() {}
  void pause() {}
  void resume() {}
  dynamic ondataavailable;
  dynamic onstop;
  dynamic onerror;
}

class _StubBlob {
  _StubBlob([dynamic parts, dynamic options]);
  int get size => 0;
  String get type => '';
  dynamic slice([int? start, int? end, String? contentType]) => null;
}

class _StubBlobPropertyBag {
  _StubBlobPropertyBag({this.type = ''});
  final String type;
}

class _StubFileReaderSync {
  String readAsDataURL(dynamic blob) => '';
}

class _StubSpeechSynthesis {
  void speak(dynamic utterance) {}
  void stop() {}
  void pause() {}
  void resume() {}
  bool get paused => false;
  bool get pending => false;
  bool get speaking => false;
  List<_StubSpeechSynthesisVoice> get voices => const [];
  dynamic onvoiceschanged;
  List<_StubSpeechSynthesisVoice> getVoices() => const [];
}

class _StubSpeechSynthesisVoice {
  _StubSpeechSynthesisVoice({this.name = '', this.lang = '', this.localService = false, this.voiceURI = ''});
  final String name;
  final String lang;
  final bool localService;
  final String voiceURI;
}

class _StubSpeechSynthesisUtterance {
  _StubSpeechSynthesisUtterance([String text = '']);
  String text = '';
  String lang = '';
  double rate = 1.0;
  double pitch = 1.0;
  double volume = 1.0;
  dynamic voice;
  dynamic onend;
  dynamic onerror;
}

class _StubMediaStreamConstraints {
  _StubMediaStreamConstraints({this.audio = true, this.video = false});
  final bool audio;
  final bool video;
}

// ── DOM stubs ─────────────────────────────────────────────────────────────────
class _StubElement {
  _StubElement();
  String get tagName => '';
  String get innerHTML => '';
  set innerHTML(String v) {}
  void appendChild(dynamic child) {}
  void removeChild(dynamic child) {}
  _StubNode? get parentNode => null;
  _StubNodeList get childNodes => _theNodeList;
  void setAttribute(String name, String value) {}
  String? getAttribute(String name) => null;
  void removeAttribute(String name) {}
  _StubElement? querySelector(String selector) => null;
  List<_StubElement> querySelectorAll(String selector) => const [];
  void insertAdjacentHTML(String position, String html) {}
}

abstract class _StubNode {}

// 简化版 NodeList - 不实现 List 接口，只提供基本方法
class _StubNodeList {
  int get length => 0;
  _StubNode? item(int index) => null;
}
final _theNodeList = _StubNodeList();

// ── Additional Web API stubs ───────────────────────────────────────────────────
class _StubMediaSession {
  _StubMediaSession();
  String get metadata => '';
  void setMetadata(dynamic metadata) {}
  void play() {}
  void pause() {}
  void stop() {}
  void seekTo(double position) {}
  void seekBy(double delta) {}
}
final _theMediaSession = _StubMediaSession();

class _StubGeolocation {
  _StubGeolocation();
  void getCurrentPosition(dynamic successCallback, [dynamic errorCallback, dynamic options]) {}
  void watchPosition(dynamic successCallback, [dynamic errorCallback, dynamic options]) => 1;
  void clearWatch(int watchId) {}
}
final _theGeolocation = _StubGeolocation();

class _StubPermissions {
  _StubPermissions();
  Future<_StubPermissionStatus> query(_StubPermissionDescriptor descriptor) async => _thePermissionStatus;
}
class _StubPermissionDescriptor {
  _StubPermissionDescriptor({required this.name});
  final String name;
}
class _StubPermissionStatus {
  _StubPermissionStatus({this.state = 'denied'});
  final String state;
  void onchange(Function? listener) {}
}
final _thePermissions = _StubPermissions();
final _thePermissionStatus = _StubPermissionStatus();

class _StubCrypto {
  _StubCrypto();
  _StubSubtleCrypto get subtle => _theSubtleCrypto;
  Uint8List get random => _theRandom;
}
class _StubSubtleCrypto {
  _StubSubtleCrypto();
  Future<dynamic> encrypt(dynamic algorithm, dynamic key, dynamic data) async => _theRandom;
  Future<dynamic> decrypt(dynamic algorithm, dynamic key, dynamic data) async => _theRandom;
  Future<dynamic> sign(dynamic algorithm, dynamic key, dynamic data) async => _theRandom;
  Future<dynamic> verify(dynamic algorithm, dynamic key, dynamic signature, dynamic data) async => true;
  Future<dynamic> digest(dynamic algorithm, dynamic data) async => _theRandom;
  Future<dynamic> generateKey(dynamic algorithm, bool extractable, List<String> keyUsages) async => _theCryptoKey;
  Future<dynamic> exportKey(String format, dynamic key, [dynamic algorithm]) async => _theRandom;
  Future<dynamic> importKey(String format, dynamic keyData, dynamic algorithm, bool extractable, List<String> keyUsages) async => _theCryptoKey;
}
final _theSubtleCrypto = _StubSubtleCrypto();
final _theRandom = Uint8List(32);
class _StubCryptoKey {
  _StubCryptoKey({this.type = 'secret', this.usages = const [], this.algorithm = 'AES-GCM'});
  final String type;
  final List<String> usages;
  final String algorithm;
}
final _theCryptoKey = _StubCryptoKey();
final _theCrypto = _StubCrypto();

class _StubHTMLAudioElement {
  _StubHTMLAudioElement([String src = '']);
  String src = '';
  double get currentTime => 0.0;
  set currentTime(double v) {}
  double get duration => 0.0;
  bool get paused => true;
  void play() async {}
  void pause() {}
  void load() {}
  void playbackRate(double rate) {}
  double get volume => 1.0;
  set volume(double v) {}
  bool get muted => false;
  set muted(bool v) {}
  void addEventListener(String type, dynamic listener) {}
  void removeEventListener(String type, dynamic listener) {}
}

// ── Window stub ───────────────────────────────────────────────────────────────
class _StubWindowComplete {
  _StubLocalStorage get localStorage => _theLocalStorage;
  _StubSessionStorage get sessionStorage => _theSessionStorage;
  _StubNavigator get navigator => _theNavigator;
  _StubSpeechSynthesis get speechSynthesis => _theSpeechSynthesis;
  _StubMediaSession get mediaSession => _theMediaSession;
  _StubGeolocation get geolocation => _theGeolocation;
  _StubPermissions get permissions => _thePermissions;
  _StubCrypto get crypto => _theCrypto;
  _StubElement Function(String tagName) get createElement => (_) => _theElement;
  
  // Constructor factories
  _StubMediaSession Function() get MediaSession => () => _theMediaSession;
  _StubBlob Function(dynamic, [dynamic]) get Blob => (_, [__]) => _theBlob;
  _StubFileReaderSync get FileReaderSync => _theFileReaderSync;
  _StubMediaRecorder Function(dynamic) get MediaRecorder => (s) => _theMediaRecorder;
  _StubSpeechSynthesisUtterance Function(String) get SpeechSynthesisUtterance => (t) => _theUtterance;
  _StubMediaStreamConstraints Function({bool audio, bool video}) get MediaStreamConstraints => ({audio = true, video = false}) => _theConstraints;
  _StubHTMLAudioElement Function(String) get Audio => (src) => _StubHTMLAudioElement(src);
}

final _theLocalStorage = _StubLocalStorage();
final _theSessionStorage = _StubSessionStorage();
final _theSpeechSynthesis = _StubSpeechSynthesis();
final _theMediaRecorder = _StubMediaRecorder();
final _theBlob = _StubBlob();
final _theFileReaderSync = _StubFileReaderSync();
final _theUtterance = _StubSpeechSynthesisUtterance();
final _theVoice = _StubSpeechSynthesisVoice();
final _theConstraints = _StubMediaStreamConstraints();
final _theElement = _StubElement();

/// Exposed complete window object for web.window.* access
// ignore: non_constant_identifier_names
final _StubWindowComplete window = _StubWindowComplete();
