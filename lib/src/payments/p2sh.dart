import 'dart:typed_data';

import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:flutter_bitcoin/flutter_bitcoin.dart';

import '../utils/constants/op.dart';
import '../utils/script.dart' as bscript;

import '../crypto.dart' as bcrypto;

class P2SH {
  final PaymentData data;
  final NetworkType network;

  P2SH({
    required this.data,
    this.network = bitcoin,
  }) {
    _init();
  }

  _init() {
    if (data.address != null) {
      _getDataFromAddress();
      _getDataFromHash();
    } else if (data.hash != null) {
      _getDataFromHash();
    } else if (data.output != null) {
      if (!isValidOutput(data.output!)) {
        throw ArgumentError("Output is invalid");
      }
      final hash = data.output!.sublist(2, 22);
      if (data.hash != null && hash != data.hash) {
        throw ArgumentError("Hash mismatch");
      }
      data.hash = hash;
      _getDataFromHash();
    } else if (data.input != null) {
      _getDataFromInput();
      _getDataFromRedeem();
      _getDataFromHash();
    } else if (data.redeem != null) {
      _getDataFromRedeem();
      _getDataFromHash();
    } else {
      throw ArgumentError("Not enough data");
    }
  }

  void _getDataFromAddress() {
    assert(data.address != null);

    Uint8List payload = bs58check.decode(data.address!);
    final version = payload[0]; //payload.buffer.asByteData().getUint8(0);
    if (version != network.scriptHash) {
      throw ArgumentError('Invalid version or Network mismatch');
    }

    final hash = payload.sublist(1);
    if (data.hash != null && hash != data.hash) {
      throw ArgumentError("Hash mismatch");
    }

    data.hash = hash;
    if (data.hash!.length != 20) {
      throw ArgumentError('Invalid address');
    }
  }

  void _getDataFromHash() {
    assert(data.hash != null);

    if (data.address == null) {
      final payload = Uint8List(21);
      payload[0] = network.scriptHash;
      payload.setRange(1, payload.length, data.hash!);
      data.address = bs58check.encode(payload);
    }
    data.output = bscript.compile([
      OPS['OP_HASH160'],
      data.hash,
      OPS['OP_EQUAL'],
    ]);
  }

  void _getDataFromInput() {
    assert(data.input != null);

    data.witness ??= [];
    List<dynamic> chunks = bscript.decompile(data.input) ?? [];

    if (chunks.isEmpty) {
      throw ArgumentError("Input too short");
    }

    final lastChunk = chunks[chunks.length - 1];
    data.redeem = PaymentData(
      output: lastChunk == OPS['OPS_FALSE']
          ? Uint8List(0)
          : lastChunk is Uint8List
              ? lastChunk
              : null,
      input: bscript.compile(chunks.sublist(0, chunks.length - 1)),
      witness: data.witness,
    );
  }

  void _getDataFromRedeem() {
    assert(data.redeem != null);

    if (data.hash == null && data.redeem!.output != null) {
      final hash = bcrypto.hash160(data.redeem!.output!);
      if (data.hash != null && hash != data.hash) {
        throw ArgumentError("Hash mismatch");
      }

      data.hash = hash;

      if (data.input == null && data.redeem!.input != null) {
        data.input = bscript.compile([
          ...(bscript.decompile(data.redeem!.input!) ?? []),
          data.redeem!.output!,
        ]);
      }
    }

    data.witness ??= data.redeem!.witness;
  }
}

isValidOutput(Uint8List data) {
  return data.length == 23 &&
      data[0] == OPS['OP_HASH160'] &&
      data[1] == 0x14 &&
      data[22] == OPS['OP_EQUAL'];
}
