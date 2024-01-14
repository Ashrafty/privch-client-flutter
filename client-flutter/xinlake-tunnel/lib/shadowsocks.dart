// ignore_for_file: file_names

import 'dart:convert';

import 'package:xinlake_text/validators.dart' as xv;

class Shadowsocks {
  // server
  String encrypt;
  String password;
  String address;
  int port;

  // remarks
  String name;
  int modified;

  // statistics
  String? geoLocation;
  int? responseTime;

  // properties
  String get id => "$address:$port";

  Shadowsocks({
    // server
    required this.encrypt,
    required this.password,
    required this.address,
    required this.port,
    // remarks
    String? name,
    int? modified,
    // statistics
    this.geoLocation,
    this.responseTime,
  })  : name = name ?? "$address-$port",
        modified = modified ?? DateTime.now().millisecondsSinceEpoch;

  Shadowsocks.fromMap(Map map)
      : encrypt = map["encrypt"],
        password = map["password"],
        address = map["address"],
        port = map["port"],
        // remarks
        name = map["name"],
        modified = map["modified"],
        // statistics
        geoLocation = map["geoLocation"],
        responseTime = map["responseTime"];

  Map<String, dynamic> toMap() {
    return {
      // server
      "port": port,
      "address": address,
      "password": password,
      "encrypt": encrypt,

      // remarks
      "name": name,
      "modified": modified,

      // statistics
      "responseTime": responseTime,
      "geoLocation": geoLocation,
    };
  }

  bool get isValid {
    return name.isNotEmpty &&
        (port > 0 && port < 65536) &&
        password.isNotEmpty &&
        encrypt.isNotEmpty &&
        encryptMethods.contains(encrypt) &&
        modified > 0 &&
        xv.isIP(address);
  }

  /// ss://BASE64-ENCODED-STRING-WITHOUT-PADDING#TAG
  /// BASE64-WITHOUT-PADDING: ss://method:password@hostname:port
  /// https://shadowsocks.org/en/config/quick-guide.html
  String encodeBase64() {
    final bytes = utf8.encode("$encrypt:$password@$address:$port");
    final code = base64.encode(bytes);
    return "ss://$code";
  }

  @override
  bool operator ==(other) {
    return other is Shadowsocks && other.port == port && other.address == address;
  }

  @override
  int get hashCode => Object.hash(port, address);

  static Shadowsocks? parserQrCode(String qrCode) {
    if (!qrCode.startsWith("ss://")) {
      return null;
    }

    // remove prefix
    final ssInfo = qrCode.substring(5);
    if (ssInfo.contains("@")) {
      // shadowsocks-android v4 generated format
      return parseV4(ssInfo);
    }

    return parse(ssInfo);
  }

  static Shadowsocks? parse(String ssInfo) {
    String ssBase64;
    String? ssTag;
    try {
      final base64tag = ssInfo.split("#");
      ssBase64 = base64.normalize(base64tag[0]);
      ssTag = base64tag.elementAtOrNull(1);
    } catch (exception) {
      return null;
    }

    final bytes = base64.decode(ssBase64);
    final ssUrl = utf8.decode(bytes).trim();

    // TODO: allow multi match?
    //shadowsocks 1.9.0
    final RegExp regUrl = RegExp(r'^(.+?):(.*)@(.+?):(\d+?)$');
    final match = regUrl.firstMatch(ssUrl);
    if (match != null && match.groupCount >= 4) {
      try {
        final encrypt = match.group(1) as String;
        final password = match.group(2) as String;
        final address = match.group(3) as String;
        final portString = match.group(4) as String;
        final port = int.parse(portString);

        return Shadowsocks(
          encrypt: encrypt,
          password: password,
          address: address,
          port: port,
          name: ssTag,
        );
      } catch (exception) {
        // ignored
      }
    }

    return null;
  }

  /// format: {BASE64@ADDRESS:PORT}, base64: {ENCRYPT:PASSWORD}
  /// This format is generated by shadowsocks-android v4
  static Shadowsocks? parseV4(String ssInfo) {
    // check ss code
    String ssEncryptBase64, ssAddressInfo;
    try {
      final info = ssInfo.split("@");
      ssEncryptBase64 = base64.normalize(info[0]);
      ssAddressInfo = info[1];
    } catch (exception) {
      return null;
    }

    // decode encrypt info
    final ssEncryptBytes = base64.decode(ssEncryptBase64);
    final ssEncryptInfo = utf8.decode(ssEncryptBytes);

    final ssEncryptPassword = ssEncryptInfo.split(":");
    if (ssEncryptPassword.length != 2) {
      return null;
    }

    final encrypt = ssEncryptPassword[0];
    final password = ssEncryptPassword[1];

    // parse address info
    final ssAddressPort = ssAddressInfo.split(":");
    if (ssAddressPort.length != 2) {
      return null;
    }

    final address = ssAddressPort[0];
    try {
      final port = int.parse(ssAddressPort[1]);
      return Shadowsocks(
        encrypt: encrypt,
        password: password,
        address: address,
        port: port,
      );
    } catch (exception) {
      // ignored
    }

    return null;
  }

  static const String encryptDefault = "aes-256-gcm";
  static const List<String> encryptMethods = [
    "2022-blake3-aes-128-gcm",
    "2022-blake3-aes-256-gcm",
    "2022-blake3-chacha20-poly1305",
    "2022-blake3-chacha8-poly1305",
    "chacha20-ietf-poly1305",
    "aes-128-gcm",
    "aes-256-gcm",
    "plain",
    "none",
  ];
}
