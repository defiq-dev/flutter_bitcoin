import 'dart:typed_data';
import 'package:flutter_bitcoin/src/payments/p2sh.dart';

import 'models/networks.dart';
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:bech32/bech32.dart';
import 'payments/index.dart' show PaymentData;
import 'payments/p2pkh.dart';
import 'payments/p2wpkh.dart';

class Address {
  static bool validateAddress(String address, [NetworkType? nw]) {
    try {
      addressToOutputScript(address, nw);
      return true;
    } catch (err) {
      return false;
    }
  }

  static Uint8List addressToOutputScript(
    String address, [
    NetworkType network = bitcoin,
  ]) {
    Uint8List? decodeBase58;
    Segwit? decodeBech32;
    try {
      decodeBase58 = bs58check.decode(address);
    } catch (err) {
      // Disregard, the null check below handles the error case.
    }
    if (decodeBase58 != null) {
      if (decodeBase58[0] == network.pubKeyHash) {
        final p2pkh = P2PKH(
          data: PaymentData(address: address),
          network: network,
        );
        return p2pkh.data.output!;
      } else if (decodeBase58[0] == network.scriptHash) {
        final p2sh = P2SH(
          data: PaymentData(address: address),
          network: network,
        );
        return p2sh.data.output!;
      }
      throw ArgumentError('Invalid version or Network mismatch');
    } else {
      try {
        decodeBech32 = segwit.decode(address);
      } catch (err) {
        // Disregard, the null check below handles the error case.
      }
      if (network.bech32 != decodeBech32?.hrp) {
        throw ArgumentError('Invalid prefix or Network mismatch');
      }
      if (decodeBech32?.version != 0) {
        throw ArgumentError('Invalid address version');
      }
      P2WPKH p2wpkh = P2WPKH(
        data: PaymentData(address: address),
        network: network,
      );
      return p2wpkh.data.output!;
    }
  }
}
