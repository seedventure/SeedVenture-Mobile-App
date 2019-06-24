import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:seed_venture/utils/address_constants.dart';
import "package:web3dart/src/utils/numbers.dart" as numbers;
import 'dart:math';
import 'package:seed_venture/blocs/config_manager_bloc.dart';
import 'package:web3dart/web3dart.dart';
import 'package:flutter/foundation.dart';
import 'package:web3dart/src/io/rawtransaction.dart';
import 'dart:async';

final ContributionBloc contributionBloc = ContributionBloc();

class ContributionBloc {
  Future<bool> contribute(
      String seedAmount, String configPassword, String fpAddress) async {
    Credentials credentials =
        await configManagerBloc.checkConfigPassword(configPassword);
    if (credentials == null) return false;

    String approveTxHash = await approve(credentials, seedAmount, fpAddress);

    if (approveTxHash != null) {
      print('approve ok!!!');

      Timer waitForApproveTimer = await waitForApproveTx(approveTxHash);

      const oneSec = const Duration(seconds: 1);
      Timer.periodic(oneSec, (Timer thisTimer) async  {
        if (!waitForApproveTimer.isActive) {
          thisTimer.cancel();
          String txHash = await holderSendSeeds(credentials, seedAmount, fpAddress);
          print('txHash');
        }
      });




    } else
      print('approve nooooo');
  }

  Future<String> _postNonce(String address) async {
    var url = "https://ropsten.infura.io/v3/2f35010022614bcb9dd4c5fefa9a64fd";

    Map txCountParams = {
      "id": "1",
      "jsonrpc": "2.0",
      "method": "eth_getTransactionCount",
      "params": ["$address", "latest"]
    };

    var response = await http.post(url,
        body: jsonEncode(txCountParams),
        headers: {'content-type': 'application/json'});

    return response.body;
  }

  static BigInt _parseNonceJSON(String nonceResponseBody) {
    return (numbers.hexToInt(jsonDecode(nonceResponseBody)['result']));
  }

  static String _parseTxHashJSON(String sendResponseBody) {
    return jsonDecode(sendResponseBody)['result'];
  }

  Future<String> _sendApproveTransaction(Credentials credentials,
      String fpAddress, String amountToApprove, BigInt nonce) async {
    String approveValuePowed =
        (double.parse(amountToApprove.replaceAll(',', '.')) * pow(10, 18))
            .toString();

    approveValuePowed =
        approveValuePowed.substring(0, approveValuePowed.length - 2);

    String hex = BigInt.parse(approveValuePowed).toRadixString(16);

    while (hex.length != 64) {
      hex = '0' + hex;
    }

    var url = "https://ropsten.infura.io/v3/2f35010022614bcb9dd4c5fefa9a64fd";
    String data = "0x095ea7b3000000000000000000000000";

    data = data + fpAddress.substring(2);

    data = data + hex;

    RawTransaction rawTx = new RawTransaction(
      nonce: nonce.toInt(),
      gasPrice: 10000000000,
      gasLimit: 70000,
      to: EthereumAddress(SeedTokenAddress).number,
      value: BigInt.from(0),
      data: numbers.hexToBytes(data),
    );

    var signed = rawTx.sign(numbers.numberToBytes(credentials.privateKey), 3);

    Map sendParams = {
      "id": "1",
      "jsonrpc": "2.0",
      "method": "eth_sendRawTransaction",
      "params": [numbers.bytesToHex(signed, include0x: true)]
    };
    var response = await http.post(url,
        body: jsonEncode(sendParams),
        headers: {'content-type': 'application/json'});
    return response.body;
  }

  Future<String> approve(
      Credentials credentials, String seedAmount, String fpAddress) async {
    String address = credentials.address.hex;
    String nonceResponse = await _postNonce(address);
    BigInt nonce = await compute(_parseNonceJSON, nonceResponse);
    String txResponse = await _sendApproveTransaction(
        credentials, fpAddress, seedAmount, nonce);
    if (!txResponse.contains('error')) {
      String txHash = await compute(_parseTxHashJSON, txResponse);
      return txHash;
    } else {
      return null;
    }
  }

  Future<String> _holderSendSeedsTransaction(Credentials credentials,
      String fpAddress, String seed, BigInt nonce) async {
    String seedPowed =
        (double.parse(seed.replaceAll(',', '.')) * pow(10, 18)).toString();

    seedPowed = seedPowed.substring(0, seedPowed.length - 2);

    String hex = BigInt.parse(seedPowed).toRadixString(16);

    while (hex.length != 64) {
      hex = '0' + hex;
    }

    var url = "https://ropsten.infura.io/v3/2f35010022614bcb9dd4c5fefa9a64fd";
    String data = "0x05f5c1b1";

    data = data + hex;

    RawTransaction rawTx = new RawTransaction(
      nonce: nonce.toInt(),
      gasPrice: 10000000000,
      gasLimit: 150000,
      to: EthereumAddress(fpAddress).number,
      value: BigInt.from(0),
      data: numbers.hexToBytes(data),
    );

    var signed = rawTx.sign(numbers.numberToBytes(credentials.privateKey), 3);

    Map sendParams = {
      "id": "1",
      "jsonrpc": "2.0",
      "method": "eth_sendRawTransaction",
      "params": [numbers.bytesToHex(signed, include0x: true)]
    };
    var response = await http.post(url,
        body: jsonEncode(sendParams),
        headers: {'content-type': 'application/json'});
    return response.body;
  }

  Future<Timer> waitForApproveTx(String txHash) async {
    const fiveSec = const Duration(seconds: 5);
    return Timer.periodic(fiveSec, (Timer t) {
      trackTransaction(txHash, t);
    });
  }

  Future<void> trackTransaction(String txHash, Timer t) async {
    var url = "https://ropsten.infura.io/v3/2f35010022614bcb9dd4c5fefa9a64fd";
    Map sendParams = {
      "id": "1",
      "jsonrpc": "2.0",
      "method": "eth_getTransactionReceipt",
      "params": [txHash]
    };
    var response = await http.post(url,
        body: jsonEncode(sendParams),
        headers: {'content-type': 'application/json'});
    Map jsonResponse = jsonDecode(response.body);

    if (jsonResponse['result'] != null) {
      t.cancel();
    }
  }

  Future<String> holderSendSeeds(
      Credentials credentials, String seedAmount, String fpAddress) async {
    String address = credentials.address.hex;
    String nonceResponse = await _postNonce(address);
    BigInt nonce = await compute(_parseNonceJSON, nonceResponse);
    String txResponse = await _holderSendSeedsTransaction(
        credentials, fpAddress, seedAmount, nonce);
    if (!txResponse.contains('error')) {
      String txHash = await compute(_parseTxHashJSON, txResponse);
      return txHash;
    } else {
      return null;
    }
  }
}
