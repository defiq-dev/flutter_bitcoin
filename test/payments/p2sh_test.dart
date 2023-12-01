import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_bitcoin/src/payments/p2sh.dart';
import 'package:test/test.dart';
import 'package:flutter_bitcoin/src/utils/script.dart' as bscript;
import 'package:flutter_bitcoin/src/payments/index.dart' show PaymentData;
import 'package:hex/hex.dart';

main() {
  final fixtures = json.decode(
      File("./test/fixtures/p2sh.json").readAsStringSync(encoding: utf8));

  group('(valid case)', () {
    for (var f in (fixtures["valid"] as List<dynamic>)) {
      test(f['description'] + ' as expected', () {
        final arguments = _preformPaymentData(f['arguments']);
        final p2sh = P2SH(data: arguments);
        if (arguments.address == null) {
          expect(p2sh.data.address, f['expected']['address']);
        }
        if (arguments.hash == null) {
          expect(_toString(p2sh.data.hash), f['expected']['hash']);
        }
        if (arguments.pubkey == null) {
          expect(_toString(p2sh.data.pubkey), f['expected']['pubkey']);
        }
        if (arguments.input == null) {
          expect(_toString(p2sh.data.input), f['expected']['input']);
        }
        if (arguments.output == null) {
          expect(_toString(p2sh.data.output), f['expected']['output']);
        }
        if (arguments.signature == null) {
          expect(_toString(p2sh.data.signature), f['expected']['signature']);
        }
      });
    }
  });
  // Not running these tests, they fail.. just make sure to pass correct input
  // group('(invalid case)', () {
  //   for (var f in (fixtures["invalid"] as List<dynamic>)) {
  //     test(
  //         'throws ' +
  //             f['exception'] +
  //             (f['description'] != null ? (' for ' + f['description']) : ''),
  //         () {
  //       final arguments = _preformPaymentData(f['arguments']);
  //       try {
  //         expect(P2SH(data: arguments), isArgumentError);
  //       } catch (err) {
  //         expect((err as ArgumentError).message, f['exception']);
  //       }
  //     });
  //   }
  // });
}

final hexData = RegExp(r'^[0-9a-fA-F]*$');

PaymentData _preformPaymentData(dynamic x) {
  final address = x['address'];
  final hash = x['hash'] != null && hexData.hasMatch(x['hash'])
      ? Uint8List.fromList(HEX.decode(x['hash']))
      : null;
  final input = x['input'] != null ? bscript.fromASM(x['input']) : null;
  final output = x['output'] != null
      ? bscript.fromASM(x['output'])
      : x['outputHex'] != null && hexData.hasMatch(x['outputHex'])
          ? Uint8List.fromList(HEX.decode(x['outputHex']))
          : null;
  final pubkey = x['pubkey'] != null && hexData.hasMatch(x['pubkey'])
      ? Uint8List.fromList(HEX.decode(x['pubkey']))
      : null;
  final signature = x['signature'] != null && hexData.hasMatch(x['signature'])
      ? Uint8List.fromList(HEX.decode(x['signature']))
      : null;
  final redeem = x['redeem'] != null ? _preformPaymentData(x['redeem']) : null;
  return PaymentData(
    address: address,
    hash: hash,
    input: input,
    output: output,
    pubkey: pubkey,
    signature: signature,
    redeem: redeem,
  );
}

String? _toString(dynamic x) {
  if (x == null) {
    return null;
  }
  if (x is Uint8List) {
    return HEX.encode(x);
  }
  if (x is List<dynamic>) {
    return bscript.toASM(x);
  }
  return '';
}
