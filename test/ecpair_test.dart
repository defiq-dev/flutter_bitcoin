import 'package:test/test.dart';
import 'package:hex/hex.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_bitcoin/src/ecpair.dart' show ECPair;
import 'package:flutter_bitcoin/src/models/networks.dart' as networks;

final ONE = HEX.decode('0000000000000000000000000000000000000000000000000000000000000001');

main() {
  final fixtures = json.decode(File('test/fixtures/ecpair.json').readAsStringSync(encoding: utf8));
  group('ECPair', () {
    group('fromPrivateKey', () {
      test('defaults to compressed', () {
        final keyPair = ECPair.fromPrivateKey(Uint8List.fromList(ONE));
        expect(keyPair.compressed, true);
      });
      test('supports the uncompressed option', () {
        final keyPair = ECPair.fromPrivateKey(Uint8List.fromList(ONE), compressed: false);
        expect(keyPair.compressed, false);
      });
      test('supports the network option', () {
        final keyPair = ECPair.fromPrivateKey(Uint8List.fromList(ONE), network: networks.testnet, compressed: false);
        expect(keyPair.network, networks.testnet);
      });
      for (var f in (fixtures['valid'] as List)) {
        test('derives public key for ${f['WIF']}', () {
          final d = Uint8List.fromList(HEX.decode(f['d']));
          final keyPair = ECPair.fromPrivateKey(d, compressed: f['compressed']);
          expect(HEX.encode(keyPair.publicKey), f['Q']);
        });
      }
      for (var f in (fixtures['invalid']['fromPrivateKey'] as List)) {
        test('throws ' + f['exception'], () {
          final d = HEX.decode(f['d']);
          try {
            expect(ECPair.fromPrivateKey(Uint8List.fromList(d)), isArgumentError);
          } catch (err) {
            expect((err as ArgumentError).message, f['exception']);
          }
        });
      }
    });
    group('fromPublicKey', () {
      for (var f in (fixtures['invalid']['fromPublicKey'] as List)) {
        test('throws ' + f['exception'], () {
          final Q = HEX.decode(f['Q']);
          try {
            expect(ECPair.fromPublicKey(Uint8List.fromList(Q)), isArgumentError);
          } catch (err) {
            expect((err as ArgumentError).message, f['exception']);
          }
        });
      }
    });
    group('fromWIF', () {
      for (var f in (fixtures['valid'] as List)) {
        test('imports ${f['WIF']}', () {
          final keyPair = ECPair.fromWIF(f['WIF']);
          var network = _getNetwork(f);
          expect(HEX.encode(keyPair.privateKey!), f['d']);
          expect(keyPair.compressed, f['compressed']);
          expect(keyPair.network, network);
        });
      }
      for (var f in (fixtures['invalid']['fromWIF'] as List)) {
        test('throws ' + f['exception'], () {
          var network = _getNetwork(f);
          try {
            expect(ECPair.fromWIF(f['WIF'], network: network), isArgumentError);
          } catch (err) {
            expect((err as ArgumentError).message, f['exception']);
          }
        });
      }
    });
    group('toWIF', () {
      for (var f in (fixtures['valid'] as List)) {
        test('export ${f['WIF']}', () {
          final keyPair = ECPair.fromWIF(f['WIF']);
          expect(keyPair.toWIF(), f['WIF']);
        });
      }
    });
    group('makeRandom', () {
      final d = Uint8List.fromList(List.generate(32, (i) => 4));
      final exWIF = 'KwMWvwRJeFqxYyhZgNwYuYjbQENDAPAudQx5VEmKJrUZcq6aL2pv';
      test('allows a custom RNG to be used', () {
        final keyPair = ECPair.makeRandom(rng: (size) {
          return d.sublist(0, size);
        });
        expect(keyPair.toWIF(), exWIF);
      });
      test('retains the same defaults as ECPair constructor', () {
        final keyPair = ECPair.makeRandom();
        expect(keyPair.compressed, true);
        expect(keyPair.network, networks.bitcoin);
      });
      test('supports the options parameter', () {
        final keyPair = ECPair.makeRandom(compressed: false, network: networks.testnet);
        expect(keyPair.compressed, false);
        expect(keyPair.network, networks.testnet);
      });
      test('throws if d is bad length', () {
        rng(int number) {
          return Uint8List(28);
        }

        try {
          ECPair.makeRandom(rng: rng);
        } catch (err) {
          expect((err as ArgumentError).message, 'Expected Buffer(Length: 32)');
        }
      });
    });
    group('.network', () {
      for (var f in (fixtures['valid'] as List)) {
        test('return ${f['network']} for ${f['WIF']}', () {
          networks.NetworkType? network = _getNetwork(f);
          final keyPair = ECPair.fromWIF(f['WIF']);
          expect(keyPair.network, network);
        });
      }
    });
  });
}

networks.NetworkType? _getNetwork(f) {
  networks.NetworkType? network;
  if (f['network'] != null) {
    if (f['network'] == 'bitcoin') {
      network = networks.bitcoin;
    } else if (f['network'] == 'testnet') {
      network = networks.testnet;
    }
  }
  return network;
}
