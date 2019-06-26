import 'package:web3dart/web3dart.dart';
import 'package:hex/hex.dart';
import 'package:flutter/services.dart';
import 'package:seed_venture/models/funding_panel_item.dart';
import 'package:seed_venture/utils/address_constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import "package:web3dart/src/utils/numbers.dart" as numbers;
import 'package:crypto/crypto.dart' as crypto;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seed_venture/blocs/onboarding_bloc.dart';
import 'dart:async';
import 'package:seed_venture/blocs/baskets_bloc.dart';
import 'package:seed_venture/models/member_item.dart';
import 'settings_bloc.dart';
import 'package:decimal/decimal.dart';
import 'dart:math';

final ConfigManagerBloc configManagerBloc = ConfigManagerBloc();

class ConfigManagerBloc {
  Map _previousConfigurationMap;
  List<FundingPanelItem> _fundingPanelItems;

  void _saveCryptoAccountInfo(Credentials credentials){
    SharedPreferences.getInstance().then((prefs){
      prefs.setString('address', credentials.address.hex);
    });
  }

  Future createConfiguration(
      Credentials walletCredentials, String password) async {

    _saveCryptoAccountInfo(walletCredentials);

    Map configurationMap = Map();
    List<FundingPanelItem> fundingPanelItems = List();

    Map localMap = {
      'lang_config_stuff': {'name': 'English (England)', 'code': 'en_EN'}
    };
    configurationMap.addAll(localMap);

    int currentBlockNumber = await getCurrentBlockNumber();
    Map lastCheckedBlockNumberMap = {
      'lastCheckedBlockNumber': currentBlockNumber
    };
    configurationMap.addAll(lastCheckedBlockNumberMap);

    await getFundingPanelItems(fundingPanelItems, configurationMap);

    Map userMapDecrypted = {
      'user': {
        'privateKey': walletCredentials.privateKey.toRadixString(16),
        'wallet': walletCredentials.address.hex,
        'list': []
      }
    };

    String realPass = generateMd5(password);
    String plainData = jsonEncode(userMapDecrypted);

    var platform = MethodChannel('seedventure.io/aes');

    var encryptedData = await platform.invokeMethod('encrypt',
        {"plainData": plainData, "realPass": realPass.toUpperCase()});

    var encryptedDataBase64 = base64.encode(utf8.encode(encryptedData));

    var hash = crypto.sha256
        .convert(utf8.encode(walletCredentials.address.hex.toLowerCase()));

    Map userMapEncrypted = {
      'user': {'data': encryptedDataBase64, 'hash': hash.toString()}
    };

    configurationMap.addAll(userMapEncrypted);

    saveConfigurationFile(configurationMap);

    this._fundingPanelItems = fundingPanelItems;

    await _getBasketTokensBalances(fundingPanelItems);

    OnBoardingBloc.setOnBoardingDone();
  }

  void saveConfigurationFile(Map configurationMap) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    String path = documentsDir.path;
    String configFilePath = '$path/configuration.json';
    File configFile = File(configFilePath);
    configFile.writeAsStringSync(jsonEncode(configurationMap));
  }

  String generateMd5(String input) {
    return crypto.md5.convert(utf8.encode(input)).toString();
  }

  Future<int> getCurrentBlockNumber() async {
    var url = "https://ropsten.infura.io/v3/2f35010022614bcb9dd4c5fefa9a64fd";
    Map callParams = {
      "id": "1",
      "jsonrpc": "2.0",
      "method": "eth_blockNumber",
      "params": []
    };

    var callResponse = await http.post(url,
        body: jsonEncode(callParams),
        headers: {'content-type': 'application/json'});

    Map resMap = jsonDecode(callResponse.body);

    return numbers.hexToInt(resMap['result']).toInt();
  }

  Future getFundingPanelItems(
      List<FundingPanelItem> fundingPanelItems, Map configurationMap) async {
    List<Map> fpMapsConfigFile = List();
    List<Map> fpMapsSharedPrefs = List();
    int length = await getLastDeployersLength();

    for (int index = 0; index < length; index++) {
      List<String> basketContracts = await getBasketContractsByIndex(
          index); // 0: Deployer, 1: AdminTools, 2: Token, 3: FundingPanel
      int exchangeRateSeed =
          await getBasketSeedExchangeRate(basketContracts[3]);
      Map latestOwnerData = await getLatestOwnerData(basketContracts[3]);
      List<Map> fpData = List();
      fpData.add(latestOwnerData);

      List fundingPanelVisualData =
          await getFundingPanelDetails(latestOwnerData['url']);

      if (fundingPanelVisualData != null) {
        List<MemberItem> members =
            await getMembersOfFundingPanel(basketContracts[3]);

        FundingPanelItem FPItem = FundingPanelItem(
            adminToolsAddress: basketContracts[1],
            tokenAddress: basketContracts[2],
            fundingPanelAddress: basketContracts[3],
            fundingPanelUpdates: fpData,
            latestDexQuotation: exchangeRateSeed.toString(),
            name: fundingPanelVisualData[0],
            description: fundingPanelVisualData[1],
            url: fundingPanelVisualData[2],
            imgBase64: fundingPanelVisualData[3],
            members: members);

        fundingPanelItems.add(FPItem);

        List<Map> memberMapsConfigFile = List();
        List<Map> membersMapsSharedPrefs = List();

        for (int i = 0; i < members.length; i++) {
          Map memberMapConfigFile = {
            'memberAddress': members[i].memberAddress,
            'memberName' : members[i].name,
            'latestIPFSUrl': members[i].ipfsUrl,
            'latestHash': members[i].hash,
          };

          memberMapsConfigFile.add(memberMapConfigFile);

          Map memberMapSP = {
            'member_address': members[i].memberAddress,
            'ipfsUrl': members[i].ipfsUrl,
            'hash': members[i].hash,
            'name': members[i].name,
            'description': members[i].description,
            'url': members[i].url,
            'imgbase64': members[i].imgBase64
          };

          membersMapsSharedPrefs.add(memberMapSP);
        }

        Map fpMapConfig = {
          'tokenAddress': FPItem.tokenAddress,
          'fundingPanelAddress': FPItem.fundingPanelAddress,
          'adminsToolsAddress': FPItem.adminToolsAddress,
          'fundingPanelName' : FPItem.name,
          'lastDEXPrice': FPItem.latestDexQuotation,
          'fundingPanelUpdates': FPItem.fundingPanelUpdates,
          'members': memberMapsConfigFile
        };

        fpMapsConfigFile.add(fpMapConfig);

        Map fpMapSP = {
          'name': FPItem.name,
          'description': FPItem.description,
          'url': FPItem.url,
          'imgBase64': FPItem.imgBase64,
          'funding_panel_address': FPItem.fundingPanelAddress,
          'token_address' : FPItem.tokenAddress,
          'admin_tools_address' : FPItem.adminToolsAddress,
          'latest_owner_data' : FPItem.fundingPanelUpdates,
          'imgbase64' : FPItem.imgBase64,
          'latest_dex_price': FPItem.latestDexQuotation,
          'members': membersMapsSharedPrefs
        };

        fpMapsSharedPrefs.add(fpMapSP);
      }
    }

    Map FPListMap = {'list': fpMapsConfigFile};

    configurationMap.addAll(FPListMap);

    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();


    sharedPreferences.setString(
        'funding_panels_data', jsonEncode(fpMapsSharedPrefs));
  }

  Future<List<MemberItem>> getMembersOfFundingPanel(
      String fundingPanelAddress) async {
    List<MemberItem> members = List();
    int membersLength = await getMembersLength(fundingPanelAddress);

    for (int i = 0; i < membersLength; i++) {
      String memberAddress =
          await getMemberAddressByIndex(i, fundingPanelAddress);
      List<String> memberData =
          await getMemberDataByAddress(fundingPanelAddress, memberAddress);
      List<String> memberJsonData =
          await getMemberJSONDataFromIPFS(memberData[0]);

      if (memberJsonData != null) {

        members.add(MemberItem(
            memberAddress: memberAddress,
            ipfsUrl: memberData[0],
            hash: memberData[1],
            name: memberJsonData[0],
            description: memberJsonData[1],
            url: memberJsonData[2],
            imgBase64: memberJsonData[3]));
      }
    }

    return members;
  }

  Future<List<String>> getMemberJSONDataFromIPFS(String ipfsURL) async {
    List<String> memberJsonData = List();

    try {
      var response = await http.get(ipfsURL).timeout(Duration(seconds: 10));
      if (response.statusCode != 200) {
        return null;
      }
      Map responseMap = jsonDecode(response.body);

      memberJsonData.add(responseMap['name']);
      memberJsonData.add(responseMap['description']);
      memberJsonData.add(responseMap['url']);
      memberJsonData.add(responseMap['image']);

      return memberJsonData;
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> getMemberDataByAddress(
      String fundingPanelAddress, String memberAddress) async {
    String data = "0xca87a8a1000000000000000000000000";

    data = data + memberAddress.substring(2);

    print(data);

    var url = "https://ropsten.infura.io/v3/2f35010022614bcb9dd4c5fefa9a64fd";
    Map callParams = {
      "id": "1",
      "jsonrpc": "2.0",
      "method": "eth_call",
      "params": [
        {
          "to": fundingPanelAddress,
          "data": data,
        },
        "latest"
      ]
    };

    var callResponse = await http.post(url,
        body: jsonEncode(callParams),
        headers: {'content-type': 'application/json'});

    Map resMap = jsonDecode(callResponse.body);

    String hash = resMap['result'].toString().substring(194, 258);

    HexDecoder a = HexDecoder();
    List byteArray = a.convert(resMap['result'].toString().substring(258));

    String ipfsUrl = utf8.decode(byteArray);

    for (int i = 0; i < ipfsUrl.length; i++) {
      if (ipfsUrl.codeUnitAt(i) == 'h'.codeUnitAt(0)) {
        for (int k = i; k < ipfsUrl.length; k++) {
          if (ipfsUrl.codeUnitAt(k) == 0) {
            ipfsUrl = ipfsUrl.substring(i, k);
            break;
          }
        }

        break;
      }
    }

    List<String> memberData = List();
    memberData.add(ipfsUrl);
    memberData.add(hash);

    return memberData;
  }

  Future<String> getMemberAddressByIndex(
      int index, String fundingPanelAddress) async {
    String data = "0x3c8c3ca6";

    String indexHex = numbers.toHex(index);

    for (int i = 0; i < 64 - indexHex.length; i++) {
      data += "0";
    }

    data += indexHex;

    print(data);

    var url = "https://ropsten.infura.io/v3/2f35010022614bcb9dd4c5fefa9a64fd";
    Map callParams = {
      "id": "1",
      "jsonrpc": "2.0",
      "method": "eth_call",
      "params": [
        {
          "to": fundingPanelAddress,
          "data": data,
        },
        "latest"
      ]
    };

    var callResponse = await http.post(url,
        body: jsonEncode(callParams),
        headers: {'content-type': 'application/json'});

    Map resMap = jsonDecode(callResponse.body);

    String address = EthereumAddress(resMap['result'].toString()).hex;

    return address;
  }

  Future<int> getMembersLength(String fundingPanelAddress) async {
    String data = "0x7351262f"; // get deployerListLength
    var url = "https://ropsten.infura.io/v3/2f35010022614bcb9dd4c5fefa9a64fd";
    Map callParams = {
      "id": "1",
      "jsonrpc": "2.0",
      "method": "eth_call",
      "params": [
        {
          "to": fundingPanelAddress,
          "data": data,
        },
        "latest"
      ]
    };

    var callResponse = await http.post(url,
        body: jsonEncode(callParams),
        headers: {'content-type': 'application/json'});

    Map resMap = jsonDecode(callResponse.body);

    return numbers.hexToInt(resMap['result']).toInt();
  }

  Future<List> getFundingPanelDetails(String ipfsUrl) async {
    try {

      print('AAAAA IPFS: ' + ipfsUrl);
      var response = await http.get(ipfsUrl).timeout(Duration(seconds: 10));
      print('BBBBBBB');

      if (response.statusCode != 200) {
        return null;
      }
      Map responseMap = jsonDecode(response.body);

      List returnFpDetails = List();

      returnFpDetails.add(responseMap['name']);
      returnFpDetails.add(responseMap['description']);
      returnFpDetails.add(responseMap['url']);
      returnFpDetails.add(responseMap['image']);

      return returnFpDetails;
    } catch (e) {
      print('error http get' + e.toString()  + ' FROM ' + ipfsUrl);
      return null;
    }
  }

  Future<int> getLastDeployersLength() async {
    String data = "0xe0118a53"; // get deployerListLength
    var url = "https://ropsten.infura.io/v3/2f35010022614bcb9dd4c5fefa9a64fd";
    Map callParams = {
      "id": "1",
      "jsonrpc": "2.0",
      "method": "eth_call",
      "params": [
        {
          "to": GlobalFactoryAddress,
          "data": data,
        },
        "latest"
      ]
    };

    var callResponse = await http.post(url,
        body: jsonEncode(callParams),
        headers: {'content-type': 'application/json'});

    Map resMap = jsonDecode(callResponse.body);

    return numbers.hexToInt(resMap['result']).toInt();
  }

  Future<List<String>> getBasketContractsByIndex(int index) async {
    String data = "0xf40e056c"; // getContractsByIndex

    String indexHex = numbers.toHex(index);

    for (int i = 0; i < 64 - indexHex.length; i++) {
      data += "0";
    }

    data += indexHex;

    print(data);

    var url = "https://ropsten.infura.io/v3/2f35010022614bcb9dd4c5fefa9a64fd";
    Map callParams = {
      "id": "1",
      "jsonrpc": "2.0",
      "method": "eth_call",
      "params": [
        {
          "to": GlobalFactoryAddress,
          "data": data,
        },
        "latest"
      ]
    };

    var callResponse = await http.post(url,
        body: jsonEncode(callParams),
        headers: {'content-type': 'application/json'});

    Map resMap = jsonDecode(callResponse.body);

    resMap['result'] = resMap['result'].toString().substring(2);

    List<String> addresses = List(4);

    addresses[0] = EthereumAddress(resMap['result']
            .toString()
            .substring(0, resMap['result'].toString().length ~/ 4))
        .hex;
    addresses[1] = EthereumAddress(resMap['result'].toString().substring(
            resMap['result'].toString().length ~/ 4,
            resMap['result'].toString().length ~/ 2))
        .hex;
    addresses[2] = EthereumAddress(resMap['result'].toString().substring(
            resMap['result'].toString().length ~/ 2,
            3 * (resMap['result'].toString().length ~/ 4)))
        .hex;
    addresses[3] = EthereumAddress(resMap['result'].toString().substring(
            3 * (resMap['result'].toString().length ~/ 4),
            resMap['result'].toString().length))
        .hex;

    print(callResponse.body);

    return addresses;
  }

  Future<int> getBasketSeedExchangeRate(String fundingPanelAddress) async {
    String data = "0x18bf6abc"; // get exchangeRateSeed
    var url = "https://ropsten.infura.io/v3/2f35010022614bcb9dd4c5fefa9a64fd";
    Map callParams = {
      "id": "1",
      "jsonrpc": "2.0",
      "method": "eth_call",
      "params": [
        {
          "to": fundingPanelAddress,
          "data": data,
        },
        "latest"
      ]
    };

    var callResponse = await http.post(url,
        body: jsonEncode(callParams),
        headers: {'content-type': 'application/json'});

    Map resMap = jsonDecode(callResponse.body);

    return numbers.hexToInt(resMap['result']).toInt();
  }

  Future<Map> getLatestOwnerData(String fundingPanelAddress) async {
    String data = "0xe4b85399"; // getOwnerData
    var url = "https://ropsten.infura.io/v3/2f35010022614bcb9dd4c5fefa9a64fd";
    Map callParams = {
      "id": "1",
      "jsonrpc": "2.0",
      "method": "eth_call",
      "params": [
        {
          "to": fundingPanelAddress,
          "data": data,
        },
        "latest"
      ]
    };

    var callResponse = await http.post(url,
        body: jsonEncode(callParams),
        headers: {'content-type': 'application/json'});

    Map resMap = jsonDecode(callResponse.body);

    print("get owner data: " + callResponse.body);

    print('hash: ' + resMap['result'].substring(66, 130));

    HexDecoder a = HexDecoder();
    List byteArray = a.convert(resMap['result'].toString().substring(130));

    String ipfsUrl = utf8.decode(byteArray);

    for (int i = 0; i < ipfsUrl.length; i++) {
      if (ipfsUrl.codeUnitAt(i) == 'h'.codeUnitAt(0)) {
        for (int k = i; k < ipfsUrl.length; k++) {
          if (ipfsUrl.codeUnitAt(k) == 0) {
            ipfsUrl = ipfsUrl.substring(i, k);
            break;
          }
        }

        break;
      }
    }

    Map latestDataUpdate = {
      'url': ipfsUrl,
      'hash': resMap['result'].substring(66, 130)
    };
    return latestDataUpdate;
  }

  Future<String> getSingleFundingPanelTokenAddress(
      String fundingPanelContractAddress) async {
    String data = "0x10fe9ae8";

    var url = "https://ropsten.infura.io/v3/2f35010022614bcb9dd4c5fefa9a64fd";
    Map callParams = {
      "id": "1",
      "jsonrpc": "2.0",
      "method": "eth_call",
      "params": [
        {
          "to": fundingPanelContractAddress,
          "data": data,
        },
        "latest"
      ]
    };

    var callResponse = await http.post(url,
        body: jsonEncode(callParams),
        headers: {'content-type': 'application/json'});

    Map resMap = jsonDecode(callResponse.body);

    print(callResponse.body);

    return EthereumAddress(resMap['result']).hex;
  }

  Future<List<String>> getEncryptedParamsFromConfigFile() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    String path = documentsDir.path;
    String configFilePath = '$path/configuration.json';
    File configFile = File(configFilePath);
    String content = configFile.readAsStringSync();
    Map configurationMap = jsonDecode(content);
    List<String> encryptedParams = List();
    encryptedParams.add(configurationMap['user']['data']);
    encryptedParams.add(configurationMap['user']['hash']);
    return encryptedParams;
  }

  Future<Map> loadPreviousConfigFile() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    String path = documentsDir.path;
    String configFilePath = '$path/configuration.json';
    File configFile = File(configFilePath);
    String content = configFile.readAsStringSync();
    Map configurationMap = jsonDecode(content);
    return configurationMap;
  }

  Future _update() async {

    if(_previousConfigurationMap == null) {
      _previousConfigurationMap = await loadPreviousConfigFile();
    }


    Map configurationMap = Map();
    List<FundingPanelItem> fundingPanelItems = List();

    Map localMap = {
      'lang_config_stuff': {'name': 'English (England)', 'code': 'en_EN'}
    };
    configurationMap.addAll(localMap);

    int currentBlockNumber = await getCurrentBlockNumber();
    Map lastCheckedBlockNumberMap = {
      'lastCheckedBlockNumber': currentBlockNumber
    };
    configurationMap.addAll(lastCheckedBlockNumberMap);

    await getFundingPanelItems(
        fundingPanelItems, configurationMap);

    List<String> encryptedParams = await getEncryptedParamsFromConfigFile();

    // Da sostituire solo i campi dei fundingPanels in futuro
    Map userMapEncrypted = {
      'user': {'data': encryptedParams[0], 'hash': encryptedParams[1]}
    };

    configurationMap.addAll(userMapEncrypted);

    saveConfigurationFile(configurationMap);

    this._fundingPanelItems = fundingPanelItems;

    _getBasketTokensBalances(fundingPanelItems);

    basketsBloc.updateBaskets();

    print('configuration updated!');

    bool areNotificationsEnabled = await SettingsBloc.areNotificationsEnabled();

    if(areNotificationsEnabled){
      await checkDifferencesBetweenConfigurations(
          _previousConfigurationMap, configurationMap);
    }

    _previousConfigurationMap = configurationMap;
  }

  Future checkDifferencesBetweenConfigurations(Map previous, Map actual) async {

    // Search for FundingPanels changes

    List previousFPList = previous['list'];
    List actualFPList = actual['list'];

    SharedPreferences prefs = await SharedPreferences.getInstance();

    List maps = jsonDecode(prefs.getString('funding_panels_data'));
    List<FundingPanelItem> fundingPanelItems = List();

    for (int i = 0; i < maps.length; i++) {

      fundingPanelItems.add(FundingPanelItem( // I only need name + fpAddress for notifications
        name: maps[i]['name'],
        fundingPanelAddress: maps[i]['funding_panel_address']

      ));
    }

    List<int> actualListUsedIndexes = List(); // Contains used indexes; the unused indexes will represent new added Incubators

    for (int i = 0; i < previousFPList.length; i++) {
      Map prevFP = previousFPList[i];
      Map actualFP;

      for(int k = 0; k < actualFPList.length; k++){
        if(actualFPList[k]['fundingPanelAddress'].toString().toLowerCase() == prevFP['fundingPanelAddress'].toString().toLowerCase()){
          actualFP = actualFPList[k];
          actualListUsedIndexes.add(k);
          break;
        }
      }

      if(actualFP != null){ // check if the incubator disappeared from list on blockchain
        if (prevFP['fundingPanelUpdates'][0]['hash'].toString().toLowerCase() !=
            actualFP['fundingPanelUpdates'][0]['hash'].toString().toLowerCase()) {

          String notificationData =
              'Documents by incubator' + prevFP['fundingPanelName'] + ' changed!';
          basketsBloc.notification(notificationData);

        }

        // checks for fp's specific members

        List<int> actualListUsedIndexesForMembers = List();

        List previousMemberList = prevFP['members'];
        List actualMemberList = actualFP['members'];

        String incubatorName = fundingPanelItems[i].name;

        for(int i = 0 ; i < previousMemberList.length; i++) {
          Map prevMember = previousMemberList[i];
          Map actualMember;

          for(int k = 0; k < actualMemberList.length; k++){
            if(actualMemberList[k]['memberAddress'].toString().toLowerCase() == prevMember['memberAddress'].toString().toLowerCase()){
              actualMember = actualMemberList[k];
              actualListUsedIndexesForMembers.add(k);
              break;
            }
          }

          if(actualMember != null) { // check if the member disappeared from list on blockchain
            if (prevMember['latestHash']
                .toString()
                .toLowerCase() !=
                actualMember['latestHash']
                    .toString()
                    .toLowerCase()) {


              String notificationData =
                  'Documents by member' + prevMember['memberName'] +
                      ' is changed! (Incubator '  + incubatorName + ')';
              basketsBloc.notification(notificationData);
            }
          }
          else{

            String notificationData =
                'member' + prevMember['memberName'] +
                    ' removed! (Incubator ' + incubatorName + ' )';
            basketsBloc.notification(notificationData);
          }

        }

        if(actualListUsedIndexesForMembers.length < actualMemberList.length){

          for(int i = 0; i < actualMemberList.length; i++){
            if(!actualListUsedIndexesForMembers.contains(i)){
              String notificationData =
                  'Member ' + actualMemberList[i]['memberName'] + ' added! (Incubator ' + incubatorName + ')';
              basketsBloc.notification(notificationData);
            }
          }
        }

      }
      else {
        String notificationData =
            'Incubator ' + prevFP['fundingPanelName'] +  ' removed!';
        basketsBloc.notification(notificationData);
      }


    }

    if(actualListUsedIndexes.length < actualFPList.length){
      for(int i = 0; i < actualFPList.length; i++){
        if(!actualListUsedIndexes.contains(i)){

          String notificationData =
              'Incubator ' + actualFPList[i]['fundingPanelName'] + ' added!';
          basketsBloc.notification(notificationData);
        }
      }
    }



  }

  void periodicUpdate() async {
    await _update();
    const secs = const Duration(seconds: 120);
    new Timer.periodic(secs, (Timer t) => _update());
  }

  // Used to contribute to a basket
  Future<Credentials> checkConfigPassword(String password) async {
    List<String> encryptedParams = await getEncryptedParamsFromConfigFile();
    String encryptedData = encryptedParams[0];
    String hash = encryptedParams[1];

    var platform = MethodChannel('seedventure.io/aes');

    var decryptedData = await platform.invokeMethod('decrypt', {
      "encrypted": utf8.decode(base64.decode(encryptedData)),
      "realPass":
          crypto.md5.convert(utf8.encode(password)).toString().toUpperCase()
    });

    try {
      Map configJson = jsonDecode(decryptedData);
      Credentials credentials =
          Credentials.fromPrivateKeyHex(configJson['user']['privateKey']);
      if (crypto.sha256
              .convert(utf8.encode(credentials.address.hex.toLowerCase()))
              .toString() ==
          hash) {
        return credentials;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  void updateHoldings(){
    if(_fundingPanelItems != null) {
      _getBasketTokensBalances(_fundingPanelItems);
    }
  }


  Future _getBasketTokensBalances(List<FundingPanelItem> fundingPanels) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String userAddress = prefs.getString('address');

    List<Map> userBasketsBalances = List();

    for(int i = 0; i < fundingPanels.length; i++){
      String tokenAddress = fundingPanels[i].tokenAddress;
      int decimals = await _getTokenDecimals(tokenAddress);
      String symbol = await _getTokenSymbol(tokenAddress);
      String balance = await _getTokenBalance(userAddress, tokenAddress, decimals);

      Map basketBalance = {
        'funding_panel_address' : fundingPanels[i].fundingPanelAddress,
        'token_address' : tokenAddress,
        'token_symbol' : symbol,
        'token_balance' : balance
      };

      userBasketsBalances.add(basketBalance);

    }

    prefs.setString('user_baskets_balances', jsonEncode(userBasketsBalances));
  }

  Future<int> _getTokenDecimals(String tokenAddress) async {
    String data = "0x313ce567";
    var url = "https://ropsten.infura.io/v3/2f35010022614bcb9dd4c5fefa9a64fd";
    Map callParams = {
      "id": "1",
      "jsonrpc": "2.0",
      "method": "eth_call",
      "params": [
        {
          "to": tokenAddress,
          "data": data,
        },
        "latest"
      ]
    };

    var callResponse = await http.post(url,
        body: jsonEncode(callParams),
        headers: {'content-type': 'application/json'});

    Map resMap = jsonDecode(callResponse.body);

    return numbers.hexToInt(resMap['result']).toInt();
  }

  Future<String> _getTokenSymbol(String tokenAddress) async {

    String data = "0x95d89b41";
    var url = "https://ropsten.infura.io/v3/2f35010022614bcb9dd4c5fefa9a64fd";
    Map callParams = {
      "id": "1",
      "jsonrpc": "2.0",
      "method": "eth_call",
      "params": [
        {
          "to": tokenAddress,
          "data": data,
        },
        "latest"
      ]
    };

    var callResponse = await http.post(url,
        body: jsonEncode(callParams),
        headers: {'content-type': 'application/json'});

    Map resMap = jsonDecode(callResponse.body);

    HexDecoder a = HexDecoder();
    List byteArray = a.convert(resMap['result'].toString().substring(2));

    String res = utf8.decode(byteArray);

    return res.replaceAll(new RegExp('[^A-Za-z0-9]'), ''); // replace all non-alphanumeric characters from res string

  }

  Future<String> _getTokenBalance(String userAddress, String tokenAddress, int decimals) async {

  userAddress = userAddress.substring(2);

    String data = "0x70a08231";

    while (userAddress.length != 64) {
      userAddress = '0' + userAddress;
    }

    data = data + userAddress;

    var url = "https://ropsten.infura.io/v3/2f35010022614bcb9dd4c5fefa9a64fd";
    Map callParams = {
      "id": "1",
      "jsonrpc": "2.0",
      "method": "eth_call",
      "params": [
        {
          "to": tokenAddress,
          "data": data,
        },
        "latest"
      ]
    };

    var callResponse = await http.post(url,
        body: jsonEncode(callParams),
        headers: {'content-type': 'application/json'});

    Map resMap = jsonDecode(callResponse.body);

    String tokenBalance = _getValueFromHex(resMap['result'].toString(), decimals);

    return tokenBalance;


  }

  String _getValueFromHex(String hexValue, int decimals) {
    hexValue = hexValue.substring(2);
    if (hexValue == '' || hexValue == '0')
      return '0.00';

    BigInt bigInt = BigInt.parse(hexValue, radix: 16);
    Decimal dec = Decimal.parse(bigInt.toString());
    Decimal x = dec / Decimal.fromInt(pow(10, decimals));
    String value = x.toString();
    if (value == '0') return '0.00';

    double doubleValue = double.parse(value);
    return doubleValue
        .toStringAsFixed(doubleValue.truncateToDouble() == doubleValue ? 0 : 2);
  }


}
