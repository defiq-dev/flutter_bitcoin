import 'package:test/test.dart';
import 'dart:io';
import 'dart:convert';
import 'package:hex/hex.dart';
import 'dart:typed_data';
import 'package:flutter_bitcoin/src/utils/script.dart' as bscript;
import 'package:flutter_bitcoin/src/transaction.dart';

main() {
  final fixtures = json.decode(File('test/fixtures/transaction.json').readAsStringSync(encoding: utf8));
  final valids = (fixtures['valid'] as List<dynamic>);

  group('Transaction', () {
    group('fromBuffer/fromHex', () {
      valids.forEach(importExport);
      (fixtures['hashForSignature'] as List<dynamic>).forEach(importExport);
      for (var f in (fixtures['invalid']['fromBuffer'] as List<dynamic>)) {
        test('throws on ${f['exception']}', () {
          try {
            expect(Transaction.fromHex(f['hex']), isArgumentError);
          } catch (err) {
            expect((err as ArgumentError).message, f['exception']);
          }
        });
      }

      test('.version should be interpreted as an int32le', () {
        final txHex = 'ffffffff0000ffffffff';
        final tx = Transaction.fromHex(txHex);
        expect(-1, tx.version);
      });
    });

    group('toBuffer/toHex', () {
      for (var f in valids) {
        test('exports ${f['description']} (${f['id']})', () {
          Transaction actual = fromRaw(f['raw'], false);
          expect(actual.toHex(), f['hex']);
        });
        if (f['whex'] != null && f['whex'] != '') {
          test('exports ${f['description']} (${f['id']}) as witness', () {
            Transaction actual = fromRaw(f['raw'], true);
            expect(actual.toHex(), f['whex']);
          });
        }
      }
    });

    group('weight/virtualSize', () {
      test('computes virtual size', () {
        for (var f in valids) {
          final txHex = (f['whex'] != null && f['whex'] != '') ? f['whex'] : f['hex'];
          final transaction = Transaction.fromHex(txHex);
          expect(transaction.virtualSize(), f['virtualSize']);
        }
      });
    });

    group('addInput', () {
      Uint8List prevTxHash =
          Uint8List.fromList(HEX.decode('ffffffff00ffff000000000000000000000000000000000000000000101010ff'));
      test('returns an index', () {
        final tx = Transaction();
        expect(tx.addInput(prevTxHash, 0), 0);
        expect(tx.addInput(prevTxHash, 0), 1);
      });
      test('defaults to empty script, and 0xffffffff SEQUENCE number', () {
        final tx = Transaction();
        tx.addInput(prevTxHash, 0);
        expect(tx.ins[0]!.script!.length, 0);
        expect(tx.ins[0]!.sequence, 0xffffffff);
      });
      for (var f in (fixtures['invalid']['addInput'] as List<dynamic>)) {
        test('throws on ' + f['exception'], () {
          final tx = Transaction();
          final hash = Uint8List.fromList(HEX.decode(f['hash']));
          try {
            expect(tx.addInput(hash, f['index']), isArgumentError);
          } catch (err) {
            expect((err as ArgumentError).message, f['exception']);
          }
        });
      }
    });

    test('addOutput returns an index', () {
      final tx = Transaction();
      expect(tx.addOutput(Uint8List(0), 0), 0);
      expect(tx.addOutput(Uint8List(0), 0), 1);
    });

    group('getHash/getId', () {
      verify(f) {
        test('should return the id for ${f['id']} (${f['description']})', () {
          final txHex = (f['whex'] != null && f['whex'] != '') ? f['whex'] : f['hex'];
          final tx = Transaction.fromHex(txHex);
          expect(HEX.encode(tx.getHash()), f['hash']);
          expect(tx.getId(), f['id']);
        });
      }

      valids.forEach(verify);
    });

    group('isCoinbase', () {
      verify(f) {
        test('should return ${f['coinbase']} for ${f['id']} (${f['description']})', () {
          final tx = Transaction.fromHex(f['hex']);
          expect(tx.isCoinbase(), f['coinbase']);
        });
      }

      valids.forEach(verify);
    });

    group('hashForSignature', () {
      for (var f in (fixtures['hashForSignature'] as List<dynamic>)) {
        test(
            'should return ${f['hash']} for ${f['description'] != null ? 'case "' + f['description'] + '"' : f['script']}',
            () {
          final tx = Transaction.fromHex(f['txHex']);
          final script = bscript.fromASM(f['script']);
          expect(HEX.encode(tx.hashForSignature(f['inIndex'], script, f['type'])), f['hash']);
        });
      }
    });
  });
}

importExport(dynamic f) {
  final id = f['id'] ?? f['hash'];
  final txHex = f['hex'] ?? f['txHex'];
  test('imports ${f['description']} ($id)', () {
    final actual = Transaction.fromHex(txHex);
    expect(actual.toHex(), txHex);
  });
}

Transaction fromRaw(raw, [isWitness]) {
  final tx = Transaction();
  tx.version = raw['version'];
  tx.locktime = raw['locktime'];

  (raw['ins'] as List<dynamic>).asMap().forEach((indx, txIn) {
    final txHash = HEX.decode(txIn['hash']);
    Uint8List? scriptSig;

    if (txIn['data'] != null) {
      scriptSig = Uint8List.fromList(HEX.decode(txIn['data']));
    } else if (txIn['script'] != null && txIn['script'] != '') {
      scriptSig = bscript.fromASM(txIn['script']);
    }
    tx.addInput(Uint8List.fromList(txHash), txIn['index'], txIn['sequence'], scriptSig);

    if (isWitness) {
      var witness = (txIn['witness'] as List<dynamic>).map((e) => HEX.decode(e.toString()) as Uint8List).toList();
      tx.setWitness(indx, witness);
    }
  });

  for (var txOut in (raw['outs'] as List<dynamic>)) {
    List<int>? script;
    if (txOut['data'] != null) {
      script = HEX.decode(txOut['data']);
    } else if (txOut['script'] != null) {
      script = bscript.fromASM(txOut['script']);
    }
    if (script != null) {
      tx.addOutput(Uint8List.fromList(script), txOut['value']);
    }
  }

  return tx;
}
