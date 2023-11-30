import 'dart:typed_data';

import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:flutter_bitcoin/flutter_bitcoin.dart';

import '../utils/constants/op.dart';
import '../utils/script.dart' as bscript;

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
      data.hash = data.output!.sublist(2, 22);
      _getDataFromHash();
    } else if (data.input != null) {
      // TODO: We don't need this at the moment, let's not implement it just yet
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
    data.hash = payload.sublist(1);
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
    }
    data.output = bscript.compile([
      OPS['OP_HASH160'],
      data.hash,
      OPS['OP_EQUAL'],
    ]);
  }
}

isValidOutput(Uint8List data) {
  return data.length == 23 &&
      data[0] == OPS['OP_HASH160'] &&
      data[1] == 0x14 &&
      data[22] == OPS['OP_EQUAL'];
}
