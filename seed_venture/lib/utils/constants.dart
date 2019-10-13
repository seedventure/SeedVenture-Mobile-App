// ROPSTEN

const String GlobalFactoryAddress = '0xf5b5042766eeb6dfc5ba8ebbafc61df26f0901da';
const String SeedTokenAddress = '0x029eb9c1810a97431200c08b827944b30f615325';
const String DexAddress = '0xe5ce0116743779b871b925db915d32025ccf2248';
const String infuraWSS = 'wss://testnet.seedventure.io'; // websocket
const String infuraHTTP = 'https://testnet.seedventure.io'; // change when mainnet
const String EtherscanURL = 'https://ropsten.etherscan.io/';
const int DefaultGasPrice = 30;
const int DefaultGasLimit = 8000000;

// topics for eth_getLogs
// Factory events
const String newPanelCreatedTopic = "0x28e958703d566ea9825155c28c95c3d92a2da219b51404343e4653bccd47525a";

// FP events
const String newSeedMaxSupplyTopic = "0x6c0400aaf859104057a4afd47301bdc6ac1829e4fd0b02292b6287ea761862e7";
const String ownerDataHashChangedTopic = "0xb792dd6e47b66c5563daf80ac4dacdf75cd44b0924c6533f71f2498a114ac0ea";
const String tokenExchangeRateChangedTopic = "0x09384e57f5d53342da2bbb810e7f68d5b6b397b491b7ae37f0b78b49d3d43ca5";
const String changeTokenExchangeRateOnTopTopic = "0xe3c38d6fd9e7c851ad71a659e56c7bff558ad76dc5a9bfe93b1423eff36456c2";
const String memberAddedTopic = "0x94d9b0a056867efca93631b338c7fde3befc3f54db36b90b8456b069385c30be";
const String memberHashChangedTopic = "0x99928ca43d8ee8b7ad3f45bfb7a95a1faed74716efc0123e21c23271da930808";
const String fundsUnlockedTopic = "0x77a5b70f4e0aa62836a5593ff0f7bea03fbd7a17df0a63cf6cd5ce0a7a25ca1c";
const String tokenMintedTopic = "0xa010600a2b0cad80fbba6228184e39b1090d487cbcde96700c76857648fa6479"; // _holderSendSeeds

// AT events
const String WLThresholdChangedTopic = "0x10b2a5b108c7f1e07744f78d98a096424f89c30fca6176cb114052d552ea4650";

// DEX events
const String tradeTopic = "0x74fe7e1f8cd2a8282b88fefc87ef874cc84ac7b165218719b0b646fb53497f32";
