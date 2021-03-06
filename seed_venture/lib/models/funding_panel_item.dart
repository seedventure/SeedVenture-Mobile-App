import 'package:seed_venture/models/member_item.dart';

class FundingPanelItem {
  // data for configuration file
  final String tokenAddress;
  final String fundingPanelAddress;
  final String adminToolsAddress;
  final Map latestOwnerData;

  // data for SharedPreferences (visualization)
  final String name;
  final String description;
  final String url;
  final String imgBase64;
  bool favorite;

  // shared
  final double seedExchangeRate;
  final double seedExchangeRateDEX;
  final double exchangeRateOnTop;
  final double whitelistThreshold;
  final List<MemberItem> members;
  final List tags;
  final List documents;
  final bool whitelisted;
  final bool blacklisted;
  final String seedTotalRaised;
  final String seedMaxSupply;
  final String totalUnlockedForStartup;
  final String tokenSymbol;
  final double WLMaxAmount;
  final double basketSuccessFee;
  final double totalPortfolioValue;
  final String portfolioCurrency;

  void setFavorite(bool favorite) {
    this.favorite = favorite;
  }

  FundingPanelItem(
      {this.tokenAddress,
      this.fundingPanelAddress,
      this.adminToolsAddress,
      this.latestOwnerData,
      this.name,
      this.description,
      this.url,
      this.imgBase64,
      this.favorite,
      this.seedExchangeRate,
      this.seedExchangeRateDEX,
      this.exchangeRateOnTop,
      this.members,
      this.tags,
      this.documents,
      this.whitelistThreshold,
      this.whitelisted,
      this.blacklisted,
      this.seedTotalRaised,
      this.seedMaxSupply,
      this.totalUnlockedForStartup,
      this.tokenSymbol,
      this.WLMaxAmount,
      this.basketSuccessFee,
      this.totalPortfolioValue,
      this.portfolioCurrency});
}
