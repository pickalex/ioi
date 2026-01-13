import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'dart:ui';
import '../models/stock_model.dart';
import '../models/favorite_model.dart';
import '../services/stock_service.dart';
import '../database/database_helper.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/favorites/favorites_bloc.dart';
import '../bloc/favorites/favorites_event.dart';
import '../bloc/favorites/favorites_state.dart';
import '../widgets/stock_widgets.dart';
import '../widgets/stock_card.dart';
import '../utils/date_util.dart';
import '../utils/debounce_throttle.dart';

class StockQuantPage extends StatefulWidget {
  const StockQuantPage({super.key});

  @override
  State<StockQuantPage> createState() => _StockQuantPageState();
}

class _StockQuantPageState extends State<StockQuantPage> {
  // Removed hardcoded _watchlist
  List<MarketIndex> _indexes = [];
  Map<String, List<TradingSuggestion>> _allDiscovery = {'buy': []};

  final TextEditingController _searchController = TextEditingController();
  List<StockInfo> _searchResults = [];
  bool _isSearching = false;
  Map<String, StockInfo> _latestFavoritePrices = {};
  Timer? _refreshTimer;
  List<StockInfo> _fundFlowRanking = [];
  bool _isLoadingFundFlow = false;
  bool _isWatchlistLoading = false;
  int _currentIndex = 0;
  StreamSubscription? _opportunitySub;

  // Sector filter for recommendations
  String _selectedSector = '全部';
  List<String> _hotSectors = [];

  DateTime? _lastPressedAt;

  @override
  void initState() {
    super.initState();

    _initData();

    // Start the global scanner when entering the page
    stockService.startScanner();
    _allDiscovery = {'buy': stockService.buyOpportunities};
    _opportunitySub = stockService.opportunityStream.listen((data) {
      if (mounted) setState(() => _allDiscovery = data);
    });
  }

  Future<void> _initData() async {
    await _fetchWatchlistData();
    stockService.updateHotSectorStocks().then((_) {
      if (mounted) {
        setState(() {
          _hotSectors = ['全部', ...stockService.sectorHotStocks.keys];
        });
      }
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      // Changed duration from 6 to 20
      _fetchWatchlistData();
    });
  }

  Future<void> _fetchWatchlistData() async {
    if (_isWatchlistLoading) return;
    _isWatchlistLoading = true;
    try {
      // 1. Fetch Market Indexes
      final indexData = await stockService.fetchMarketIndexes();

      // 2. Fetch Latest Prices for Favorites
      final favoritesState = context.read<FavoritesBloc>().state;
      List<FavoriteRecommendation> favorites = [];
      if (favoritesState is FavoritesLoaded) {
        favorites = favoritesState.favorites;
      }

      if (favorites.isNotEmpty) {
        final symbols = favorites.map((f) => f.snapshot.symbol).toList();
        final latestStocks = await stockService.fetchStocks(symbols);
        // ...
        if (mounted) {
          setState(() {
            _indexes = indexData;
            _hotSectors = ['全部', ...stockService.sectorHotStocks.keys];
            for (var stock in latestStocks) {
              _latestFavoritePrices[stock.symbol] = stock;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _indexes = indexData;
            _hotSectors = ['全部', ...stockService.sectorHotStocks.keys];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching watchlist data: $e");
    } finally {
      _isWatchlistLoading = false;
    }
  }

  Future<void> _fetchFundFlowRanking() async {
    if (_isLoadingFundFlow) return;
    setState(() => _isLoadingFundFlow = true);
    try {
      final ranking = await stockService.fetchFundFlowRanking();
      if (!mounted) return;
      setState(() {
        _fundFlowRanking = ranking;
        _isLoadingFundFlow = false;
      });
    } catch (e) {
      debugPrint("StockQuantPage: Error fetching fund flow: $e");
      if (mounted) setState(() => _isLoadingFundFlow = false);
    }
  }

  Future<void> _handleSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }
    setState(() => _isSearching = true);

    Debouncer.run(
      tag: 'stock_search',
      duration: const Duration(milliseconds: 500),
      action: () async {
        try {
          List<StockInfo> results = [];

          // 1. Try Local DB Search (covers both code and name)
          final dbMatches = await DatabaseHelper.instance.searchStocks(query);
          if (dbMatches.isNotEmpty) {
            final symbols = dbMatches
                .map((m) => m['symbol'] as String)
                .toList();
            // Limit to top 20 to avoid slow API
            if (symbols.isNotEmpty) {
              results = await stockService.fetchStocks(
                symbols.take(20).toList(),
              );
            }
          }

          // 2. If no local results, and looks like a code, try direct API
          if (results.isEmpty && RegExp(r'^\d+$').hasMatch(query)) {
            String symbol = query;
            if (query.length == 6) {
              symbol = query.startsWith('6') ? 'sh$query' : 'sz$query';
            }
            final apiResults = await stockService.fetchStocks([
              symbol.toLowerCase(),
            ]);
            if (apiResults.isNotEmpty) results.addAll(apiResults);
          }

          if (!mounted) return;
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        } catch (e) {
          debugPrint('Search error: $e');
          if (mounted) setState(() => _isSearching = false);
        }
      },
    );
  }

  void _addToWatchlist(String symbol) async {
    // Check using Bloc state - simplified for now, just dispatch add
    final stocks = await stockService.fetchStocks([symbol]);
    if (stocks.isNotEmpty) {
      final stock = stocks.first;
      final suggestion = stockService.getSuggestion(stock);
      context.read<FavoritesBloc>().add(AddFavorite(stock, suggestion));

      SmartDialog.showToast("已添加 ${stock.name} 到收藏");
    }
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _opportunitySub?.cancel();
    _refreshTimer?.cancel();
    _searchController.dispose();
    stockService.stopScanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buyOpps = _allDiscovery['buy'] ?? [];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final now = DateTime.now();
        if (_lastPressedAt == null ||
            now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          SmartDialog.showToast('再按一次退出应用');
          return;
        }

        // Allow app to exit
        await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            '全市场智能扫描',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          // Remove back button since it's the main page now
          automaticallyImplyLeading: false,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomeView(buyOpps.length),
                _buildRecommendedView(buyOpps),
                _buildFundFlowRankingView(),
                _buildFavoritesView(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            if (index == 2) _fetchFundFlowRanking();
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF16213E),
          selectedItemColor: Colors.cyanAccent,
          unselectedItemColor: Colors.white38,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "首页"),
            BottomNavigationBarItem(icon: Icon(Icons.recommend), label: "推荐"),
            BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: "资金流"),
            BottomNavigationBarItem(icon: Icon(Icons.star), label: "我的收藏"),
          ],
        ),
        floatingActionButton: ValueListenableBuilder<TradingSuggestion?>(
          valueListenable: stockService.strongBuyAlert,
          builder: (context, suggestion, _) {
            if (suggestion == null) return const SizedBox.shrink();
            return FloatingActionButton.extended(
              onPressed: () {
                stockService.strongBuyAlert.value = null; // Clear on tap
                _showDetails(suggestion.stock, suggestion);
              },
              backgroundColor: const Color(0xFFEB4436),
              icon: const Icon(Icons.flash_on, color: Colors.white),
              label: Text(
                '潜力股发现: ${suggestion.stock.name}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHomeView(int oppCount) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: MarketPulse(indexes: _indexes)),
        const SliverToBoxAdapter(child: RiskWarning()),
        SliverToBoxAdapter(
          child: GestureDetector(
            onTap: () => setState(() => _currentIndex = 1),
            child: ScannerStatus(count: oppCount),
          ),
        ),
        SliverToBoxAdapter(child: _buildSearchBar()),
        if (_searchController.text.isNotEmpty) _buildSearchResultsSliver(),
      ],
    );
  }

  Widget _buildSearchResultsSliver() {
    if (_isSearching) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => StockCard(
            stock: _searchResults[index],
            suggestion: null,
            isSearch: true,
            onTap: () => _showDetails(_searchResults[index], null),
            favoriteButton: Builder(
              builder: (context) {
                final isFav = context.select<FavoritesBloc, bool>((bloc) {
                  if (bloc.state is FavoritesLoaded) {
                    return (bloc.state as FavoritesLoaded).favorites.any(
                      (f) => f.snapshot.symbol == _searchResults[index].symbol,
                    );
                  }
                  return false;
                });

                return IconButton(
                  icon: Icon(
                    isFav ? Icons.check_circle : Icons.add_circle,
                    color: Colors.cyanAccent,
                    size: 20,
                  ),
                  onPressed: () {
                    if (!isFav) _addToWatchlist(_searchResults[index].symbol);
                  },
                );
              },
            ),
          ),
          childCount: _searchResults.length,
        ),
      ),
    );
  }

  Widget _buildRecommendedView(List<TradingSuggestion> buyOpps) {
    final filteredBuy = _filterRecommendations(buyOpps);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Pinned Header: Title & Sector Tags
        SliverPersistentHeader(
          pinned: true,
          delegate: StickyHeaderDelegate(
            minHeight: 110,
            maxHeight: 110,
            child: Container(
              color: const Color(0xFF0F2027), // Match background
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      "买入精选",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    height: 36,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _hotSectors.length,
                      itemBuilder: (context, index) {
                        final sector = _hotSectors[index];
                        final isSelected = _selectedSector == sector;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedSector = sector);
                            stockService.setScanningSector(
                              sector == '全部' ? null : sector,
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.cyanAccent.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.cyanAccent
                                    : Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                sector,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.cyanAccent
                                      : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white10),
                ],
              ),
            ),
          ),
        ),

        // List View
        if (filteredBuy.isEmpty)
          SliverFillRemaining(
            child: _buildDiscoveryView(filteredBuy, "当前暂无买入机会，后台持续捕捉中..."),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final suggestion = filteredBuy[index];
                return StockCard(
                  stock: suggestion.stock,
                  suggestion: suggestion,
                  onTap: () => _showDetails(suggestion.stock, suggestion),
                );
              }, childCount: filteredBuy.length),
            ),
          ),
      ],
    );
  }

  List<TradingSuggestion> _filterRecommendations(List<TradingSuggestion> opps) {
    if (_selectedSector == '全部') return opps;

    // Check both stock.industry and the sectorHotStocks map for better compatibility
    final sectorSymbols = stockService.sectorHotStocks[_selectedSector] ?? [];
    return opps.where((s) {
      return s.stock.industry == _selectedSector ||
          sectorSymbols.contains(s.stock.symbol);
    }).toList();
  }

  Widget _buildFavoritesView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.star, color: Colors.amberAccent, size: 24),
              const SizedBox(width: 8),
              const Text(
                "我的收藏",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        Expanded(child: _buildWatchlist()),
      ],
    );
  }

  Widget _buildFundFlowRankingView() {
    return Column(
      children: [
        _buildFundFlowHeader(),
        Expanded(
          child: _isLoadingFundFlow
              ? const Center(
                  child: CupertinoActivityIndicator(color: Colors.cyanAccent),
                )
              : _fundFlowRanking.isEmpty
              ? const Center(
                  child: Text("暂无数据", style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _fundFlowRanking.length,
                  itemBuilder: (context, index) {
                    final stock = _fundFlowRanking[index];
                    return _buildFundFlowListItem(stock, index + 1);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFundFlowHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Icon(Icons.show_chart, color: Colors.cyanAccent, size: 24),
          const SizedBox(width: 8),
          const Text(
            "主力净流入排行",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            "今日 Top 20",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundFlowListItem(StockInfo stock, int rank) {
    return InkWell(
      onTap: () => _showDetails(stock, null),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rank <= 3
                        ? Colors.amberAccent.withOpacity(0.2)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    rank.toString(),
                    style: TextStyle(
                      color: rank <= 3 ? Colors.amberAccent : Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stock.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        stock.symbol.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      stock.current.toStringAsFixed(2),
                      style: TextStyle(
                        color: stock.changePercent >= 0
                            ? Colors.redAccent
                            : Colors.greenAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${stock.changePercent >= 0 ? "+" : ""}${stock.changePercent.toStringAsFixed(2)}%",
                      style: TextStyle(
                        color: stock.changePercent >= 0
                            ? Colors.redAccent
                            : Colors.greenAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            FundFlowDistributionBar(stock: stock),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveryView(List<TradingSuggestion> opps, String emptyMsg) {
    if (opps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CupertinoActivityIndicator(
              color: Colors.cyanAccent,
              radius: 14,
            ),
            const SizedBox(height: 20),
            Text(
              emptyMsg,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final suggestion = opps[index];
              return StockCard(
                stock: suggestion.stock,
                suggestion: suggestion,
                onTap: () => _showDetails(suggestion.stock, suggestion),
              );
            }, childCount: opps.length),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "手动搜索股票（自动扫描中，无需手动）",
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: Colors.white70,
              size: 18,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 12,
            ),
          ),
          onChanged: _handleSearch,
        ),
      ),
    );
  }

  Widget _buildWatchlist() {
    return BlocBuilder<FavoritesBloc, FavoritesState>(
      builder: (context, state) {
        if (state is FavoritesLoading) {
          return const Center(
            child: CupertinoActivityIndicator(color: Colors.cyanAccent),
          );
        }
        if (state is FavoritesError) {
          return Center(
            child: Text(
              state.message,
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }
        if (state is FavoritesLoaded) {
          if (state.favorites.isEmpty) {
            return const Center(
              child: Text(
                "暂无收藏，快去添加吧",
                style: TextStyle(color: Colors.white38),
              ),
            );
          }
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final fav = state.favorites[index];
                    return Dismissible(
                      key: Key(fav.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              "移除",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        return await showCupertinoDialog<bool>(
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: const Text('确认删除'),
                            content: const Text('您确定要将该股票从收藏中移除吗？'),
                            actions: [
                              CupertinoDialogAction(
                                child: const Text('取消'),
                                onPressed: () => Navigator.pop(context, false),
                              ),
                              CupertinoDialogAction(
                                isDestructiveAction: true,
                                child: const Text('删除'),
                                onPressed: () => Navigator.pop(context, true),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        context.read<FavoritesBloc>().add(
                          RemoveFavorite(fav.id),
                        );
                      },
                      child: StockCard(
                        stock:
                            _latestFavoritePrices[fav.snapshot.symbol] ??
                            fav.snapshot,
                        suggestion: fav.suggestion,
                        snapshotPrice: fav.snapshot.current,
                        collectionTime: fav.capturedAt,
                        onTap: () {
                          final currentStock =
                              _latestFavoritePrices[fav.snapshot.symbol] ??
                              fav.snapshot;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RecommendationComparisonPage(
                                    favorite: fav,
                                    currentPrice: currentStock.current,
                                  ),
                            ),
                          );
                        },
                      ),
                    );
                  }, childCount: state.favorites.length),
                ),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _showDetails(StockInfo stock, TradingSuggestion? suggestion) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          StockDetailSheet(initialStock: stock, initialSuggestion: suggestion),
    );
  }
}

class StockDetailSheet extends StatefulWidget {
  final StockInfo initialStock;
  final TradingSuggestion? initialSuggestion;

  const StockDetailSheet({
    super.key,
    required this.initialStock,
    this.initialSuggestion,
  });

  @override
  State<StockDetailSheet> createState() => _StockDetailSheetState();
}

class _StockDetailSheetState extends State<StockDetailSheet> {
  late StockInfo _stock;
  TradingSuggestion? _suggestion;
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _stock = widget.initialStock;
    _suggestion = widget.initialSuggestion;
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _fetchLatestData(); // Fetch immediately
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      _fetchLatestData();
    });
  }

  Future<void> _fetchLatestData() async {
    if (_isRefreshing) return;
    try {
      if (mounted) setState(() => _isRefreshing = true);
      // Fetch latest price and order book using more detailed API
      final updated = await stockService.fetchStockDetail(_stock.symbol);
      if (updated == null) {
        if (mounted) setState(() => _isRefreshing = false);
        return;
      }

      // Also enrich with indicators (K-lines)
      var detailed = await stockService.enrichWithIndicators(updated);

      if (!mounted) return;

      final newSuggestion = stockService.getSuggestion(detailed);

      setState(() {
        _stock = detailed;
        _suggestion = newSuggestion;
        _isRefreshing = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _stock.isUp ? Colors.redAccent : Colors.greenAccent;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1A2E).withValues(alpha: 0.95),
              const Color(0xFF16213E).withValues(alpha: 0.9),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white10, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "股票量化详情",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    Opacity(
                      opacity: _isRefreshing ? 1.0 : 0.0,
                      child: CupertinoActivityIndicator(
                        radius: 6,
                        color: Colors.cyanAccent,
                        animating: _isRefreshing,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.cyanAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent,
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "实时极速同步",
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _stock.name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 2),
                                      blurRadius: 4,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Builder(
                                builder: (context) {
                                  // Parse symbol: sh600201 -> [SH] 600201
                                  final symbol = _stock.symbol.toUpperCase();
                                  String prefix = "";
                                  String code = symbol;
                                  if (symbol.startsWith("SH") ||
                                      symbol.startsWith("SZ")) {
                                    prefix = "[${symbol.substring(0, 2)}]";
                                    code = symbol.substring(2);
                                  }

                                  return Row(
                                    children: [
                                      Text(
                                        "$prefix $code",
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 14,
                                          fontFamily: 'Courier',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () {
                                          Clipboard.setData(
                                            ClipboardData(text: code),
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).hideCurrentSnackBar();
                                          SmartDialog.showToast(
                                            "股票代码已复制到剪贴板",
                                            alignment: Alignment.center,
                                          );
                                        },
                                        overlayColor: WidgetStateProperty.all(
                                          Colors.transparent,
                                        ),
                                        child: const Icon(
                                          Icons.copy_rounded,
                                          color: Colors.white38,
                                          size: 14,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _stock.current.toStringAsFixed(2),
                              style: TextStyle(
                                color: color,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Courier',
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                    color: Colors.black.withOpacity(0.5),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${_stock.isUp ? "+" : ""}${_stock.changePercent.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: color,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FundFlowDistributionBar(stock: _stock),
                    const SizedBox(height: 24),
                    // Mini K-Line Chart with Glass Effect
                    if (_stock.kLines.isNotEmpty)
                      Container(
                        height: 200,
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.05),
                            width: 1,
                          ),
                        ),
                        child: _KLineInteractiveContainer(stock: _stock),
                      ),
                    if (_stock.indicators != null) ...[
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildIndicatorPill(
                              "MA5",
                              _stock.indicators!.ma5.toStringAsFixed(2),
                              Colors.amberAccent,
                            ),
                            const SizedBox(width: 10),
                            _buildIndicatorPill(
                              "MA10",
                              _stock.indicators!.ma10.toStringAsFixed(2),
                              Colors.blueAccent,
                            ),
                            const SizedBox(width: 10),
                            _buildIndicatorPill(
                              "MA20",
                              _stock.indicators!.ma20.toStringAsFixed(2),
                              Colors.purpleAccent,
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),
                    if (_suggestion != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getActionColor(
                                _suggestion!.action,
                              ).withOpacity(0.15),
                              Colors.white.withOpacity(0.02),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _getActionColor(
                              _suggestion!.action,
                            ).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  color: _getActionColor(_suggestion!.action),
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getShortLabel(_suggestion!.action),
                                  style: TextStyle(
                                    color: _getActionColor(_suggestion!.action),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.cyanAccent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.cyanAccent.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        "模型评分",
                                        style: TextStyle(
                                          color: Colors.cyanAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "${(100 * _suggestion!.confidence).toInt()}",
                                        style: const TextStyle(
                                          color: Colors.cyanAccent,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'Courier',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _suggestion!.reason,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.6,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _buildMiniTag(
                                  "量比 ${_stock.quantityRatio.toStringAsFixed(1)}",
                                  _stock.quantityRatio > 1.5
                                      ? Colors.orangeAccent
                                      : Colors.white24,
                                ),
                                const SizedBox(width: 10),
                                _buildMiniTag(
                                  "换手 ${_stock.turnoverRate.toStringAsFixed(1)}%",
                                  _stock.turnoverRate > 5
                                      ? Colors.purpleAccent
                                      : Colors.white24,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    _buildSectionHeader("5档盘口详情"),
                    const SizedBox(height: 16),
                    _buildOrderBook(_stock),
                    const SizedBox(height: 32),
                    _buildSectionHeader("扫描引擎详情"),
                    const SizedBox(height: 16),
                    if (_stock.indicators != null) ...[
                      _buildIndItem(
                        "RSI (14) 强弱",
                        _stock.indicators!.rsi.toStringAsFixed(2),
                        desc: "超买超卖指标。<30为底背离，>70为超买。",
                      ),
                      _buildIndItem(
                        "MACD 趋势强弱",
                        _stock.indicators!.macdHist.toStringAsFixed(2),
                        desc:
                            "由 DIFF (快线) 和 DEA (慢线) 计算得出。红柱增长代表多头动能增强，是系统判断坚决度的重要依据。",
                      ),
                      _buildIndItem(
                        "MACD 快线 (DIFF)",
                        _stock.indicators!.macd.toStringAsFixed(2),
                        desc: "反映短期价格波动。DIFF 向上穿越 DEA (金叉) 是系统推荐加分的关键转折点。",
                      ),
                      _buildIndItem(
                        "均线系统 (MA)",
                        "多头排列",
                        desc: "5/10/20 日均价。当 5 > 20 且股价在均线上方时，系统会给予显著的加分。",
                      ),
                      _buildIndItem(
                        "20日均线差值",
                        (_stock.current - _stock.indicators!.ma20)
                            .toStringAsFixed(2),
                        desc: "股价偏离乖离度。>0代表趋势向上支撑。",
                      ),
                      _buildIndItem(
                        "当前量比",
                        _stock.quantityRatio.toStringAsFixed(2),
                        desc: "成交活跃度。>1.5代表活跃，>3.0为放量。",
                      ),
                      _buildIndItem(
                        "今日换手",
                        "${_stock.turnoverRate.toStringAsFixed(2)}%",
                        desc: "人气指标。1-3%稳定，>5%为活跃资金进入。",
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: BlocBuilder<FavoritesBloc, FavoritesState>(
                      builder: (context, state) {
                        bool isFavorited = false;
                        String? favId;
                        if (state is FavoritesLoaded) {
                          try {
                            final fav = state.favorites.firstWhere(
                              (f) => f.snapshot.symbol == _stock.symbol,
                            );
                            isFavorited = true;
                            favId = fav.id;
                          } catch (_) {}
                        }

                        return InkWell(
                          onTap: () {
                            if (isFavorited && favId != null) {
                              context.read<FavoritesBloc>().add(
                                RemoveFavorite(favId),
                              );
                            } else if (_suggestion != null) {
                              context.read<FavoritesBloc>().add(
                                AddFavorite(_stock, _suggestion!),
                              );
                            } else {
                              SmartDialog.showToast(
                                "正在获取建议数据，请稍后...",
                                alignment: Alignment.center,
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isFavorited
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: Colors.amberAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isFavorited ? "已收藏" : "收藏",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3A7BD5).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "完成查看",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.cyanAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 17,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  String _getShortLabel(TradeAction action) {
    switch (action) {
      case TradeAction.strongBuy:
      case TradeAction.buy:
        return "买入推荐";
      case TradeAction.strongSell:
      case TradeAction.sell:
        return "卖出推荐";
      case TradeAction.hold:
        return "持有不动";
      case TradeAction.neutral:
        return "观望中";
    }
  }

  Color _getActionColor(TradeAction action) {
    switch (action) {
      case TradeAction.strongBuy:
      case TradeAction.buy:
        return Colors.redAccent;
      case TradeAction.strongSell:
      case TradeAction.sell:
        return Colors.greenAccent;
      case TradeAction.hold:
        return Colors.orangeAccent;
      case TradeAction.neutral:
        return Colors.blueAccent;
    }
  }

  Widget _buildIndicatorPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildIndItem(String label, String value, {String? desc}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (desc != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                desc,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          const SizedBox(height: 4),
          const Divider(color: Colors.white10, height: 1),
        ],
      ),
    );
  }

  Widget _buildOrderBook(StockInfo stock) {
    // Determine if any level (bid or ask) has volume >= 10,000
    final allVolumes = [
      ...stock.asks.map((e) => e.volume),
      ...stock.bids.map((e) => e.volume),
    ];
    final bool useWan = allVolumes.any((v) => v >= 10000);

    return Column(
      children: [
        ...List.generate(stock.asks.length, (index) {
          final level = stock.asks[stock.asks.length - 1 - index];
          return _buildOrderRow(
            "卖${stock.asks.length - index}",
            level.price,
            level.volume,
            Colors.greenAccent,
            useWan: useWan,
          );
        }),
        const Divider(color: Colors.white10),
        ...List.generate(stock.bids.length, (index) {
          final level = stock.bids[index];
          return _buildOrderRow(
            "买${index + 1}",
            level.price,
            level.volume,
            Colors.redAccent,
            useWan: useWan,
          );
        }),
      ],
    );
  }

  Widget _buildOrderRow(
    String label,
    double price,
    double volume,
    Color color, {
    bool useWan = false,
  }) {
    String volStr;
    if (useWan && volume >= 100) {
      volStr = "${(volume / 10000).toStringAsFixed(2)} 万";
    } else {
      volStr = "${volume.toInt()} 手";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          Text(
            price.toStringAsFixed(2),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            volStr,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class MiniKLinePainter extends CustomPainter {
  final StockInfo stock;
  final int? selectedIndex;

  // Professional A-share colors
  static const Color upColor = Color(0xFFEB4436);
  static const Color downColor = Color(0xFF4CAF50);
  static const Color gridColor = Color(0x1FDDDDDD);

  final bool showVolume;

  MiniKLinePainter(this.stock, {this.selectedIndex, this.showVolume = false});

  @override
  void paint(Canvas canvas, Size size) {
    final points = stock.kLines;
    if (points.isEmpty && stock.current == 0) return;

    // Synthesize display points: historical + today's real-time candle
    List<KLinePoint> displayPoints = points.length > 50
        ? points.sublist(points.length - 50)
        : List.from(points);

    // If today's data is not in kLines (usually historical ends yesterday), add it
    final todayStr = DateTime.now()
        .toString()
        .split(' ')[0]
        .replaceAll('-', '');
    bool hasToday =
        displayPoints.isNotEmpty &&
        (displayPoints.last.time.replaceAll('-', '') == todayStr ||
            displayPoints.last.time == stock.date);

    if (!hasToday && stock.current > 0) {
      displayPoints.add(
        KLinePoint(
          time: "今日",
          open: stock.open > 0 ? stock.open : stock.yesterdayClose,
          close: stock.current,
          high: stock.high > 0
              ? stock.high
              : max(stock.current, stock.yesterdayClose),
          low: stock.low > 0
              ? stock.low
              : min(stock.current, stock.yesterdayClose),
          volume: stock.volume,
        ),
      );
    }

    double maxVal = displayPoints.map((p) => p.high).reduce(max);
    double minVal = displayPoints.map((p) => p.low).reduce(min);

    // Safety padding for max/min
    maxVal *= 1.01;
    minVal *= 0.99;

    final double range = maxVal - minVal;
    if (range == 0) return;

    final double widthPerPoint = size.width / displayPoints.length;
    final double candleWidth = widthPerPoint * 0.7;

    // Calculate MAs based on full history for accuracy
    final ma5List = _calculateMA(points, 5);
    final ma10List = _calculateMA(points, 10);
    final ma20List = _calculateMA(points, 20);

    final startIndex = points.length > 50 ? points.length - 50 : 0;

    // Draw Background Grid
    _drawGrid(canvas, size);

    for (int i = 0; i < displayPoints.length; i++) {
      final p = displayPoints[i];
      final x = i * widthPerPoint + widthPerPoint / 2;

      final double openY =
          size.height - ((p.open - minVal) / range * size.height);
      final double closeY =
          size.height - ((p.close - minVal) / range * size.height);
      final double highY =
          size.height - ((p.high - minVal) / range * size.height);
      final double lowY =
          size.height - ((p.low - minVal) / range * size.height);

      // Fix Color Logic: Use change from previous close for better daily sentiment
      // This solves the "down but red" issue if open > close but today > yesterday close
      Color color;
      double prevClose;
      if (i > 0) {
        prevClose = displayPoints[i - 1].close;
      } else if (points.isNotEmpty && startIndex > 0) {
        prevClose = points[startIndex - 1].close;
      } else {
        prevClose = p.open;
      }

      // Special case: for "Today" synthetic candle, force comparison with yesterdayClose
      if (p.time == "今日") {
        prevClose = stock.yesterdayClose > 0 ? stock.yesterdayClose : prevClose;
      }

      color = p.close >= prevClose ? upColor : downColor;

      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.2; // Slightly thicker for professional look

      // Draw wicks (Split to avoid penetrating hollow bodies)
      final bodyTop = min(openY, closeY);
      final bodyBottom = max(openY, closeY);
      canvas.drawLine(Offset(x, highY), Offset(x, bodyTop), paint);
      canvas.drawLine(Offset(x, bodyBottom), Offset(x, lowY), paint);

      // Draw body
      final bodyRect = Rect.fromLTRB(
        x - candleWidth / 2,
        bodyTop,
        x + candleWidth / 2,
        bodyBottom,
      );

      if (bodyRect.height < 1.0) {
        // Flat candle
        canvas.drawLine(
          Offset(x - candleWidth / 2, openY),
          Offset(x + candleWidth / 2, openY),
          paint,
        );
      } else {
        // Hollow for Yang (Price Close > Open), Solid for Yin (Price Close < Open)
        // Note: Color is based on PrevClose, but Hollow/Solid is based on Open/Close
        if (p.close >= p.open) {
          paint.style = PaintingStyle.stroke;
          paint.strokeWidth = 1.0;
          canvas.drawRect(bodyRect, paint);
        } else {
          paint.style = PaintingStyle.fill;
          canvas.drawRect(bodyRect, paint);
        }
      }

      // Draw volume if requested
      if (showVolume) {
        _drawVolumeItem(
          canvas,
          size,
          p,
          i,
          displayPoints.length,
          widthPerPoint,
          prevClose,
        );
      }
    }

    // Draw MA lines
    _drawMALine(
      canvas,
      ma5List,
      startIndex,
      displayPoints.length,
      widthPerPoint,
      size,
      minVal,
      range,
      Colors.yellow,
    );
    _drawMALine(
      canvas,
      ma10List,
      startIndex,
      displayPoints.length,
      widthPerPoint,
      size,
      minVal,
      range,
      Colors.orange,
    );
    _drawMALine(
      canvas,
      ma20List,
      startIndex,
      displayPoints.length,
      widthPerPoint,
      size,
      minVal,
      range,
      Colors.purpleAccent,
    );

    // Draw Current Price Line
    final double latestY =
        size.height - ((stock.current - minVal) / range * size.height);
    final dashedPaint = Paint()
      ..color = (stock.isUp ? upColor : downColor).withOpacity(0.5)
      ..strokeWidth = 0.8;

    for (double i = 0; i < size.width; i += 5) {
      canvas.drawLine(Offset(i, latestY), Offset(i + 2, latestY), dashedPaint);
    }

    // Draw Y-Axis Price Scales
    _drawPriceScale(canvas, size, minVal, maxVal);

    // Draw Interaction Overlay
    if (selectedIndex != null && selectedIndex! < displayPoints.length) {
      _drawInteraction(
        canvas,
        size,
        displayPoints,
        selectedIndex!,
        widthPerPoint,
        minVal,
        range,
        points,
        startIndex,
      );
    }
  }

  void _drawPriceScale(Canvas canvas, Size size, double minVal, double maxVal) {
    const int levels = 4;
    final double step = (maxVal - minVal) / (levels - 1);
    final textStyle = TextStyle(
      color: Colors.white.withOpacity(0.4),
      fontSize: 9,
      fontFamily: 'Courier',
    );

    for (int i = 0; i < levels; i++) {
      final price = maxVal - (i * step);
      final y = (i * size.height) / (levels - 1);

      final textPainter = TextPainter(
        text: TextSpan(text: price.toStringAsFixed(2), style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width - textPainter.width, y - textPainter.height / 2),
      );
    }
  }

  void _drawInteraction(
    Canvas canvas,
    Size size,
    List<KLinePoint> displayPoints,
    int index,
    double widthPerPoint,
    double minVal,
    double range,
    List<KLinePoint> allPoints,
    int startIndex,
  ) {
    final p = displayPoints[index];
    final x = index * widthPerPoint + widthPerPoint / 2;
    final y = size.height - ((p.close - minVal) / range * size.height);

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 0.8;

    // Vertical line
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    // Horizontal line
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    // Circle at close price
    canvas.drawCircle(Offset(x, y), 4, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.black);

    // Calculate Change for display
    double prevClose;
    if (index > 0) {
      prevClose = displayPoints[index - 1].close;
    } else if (allPoints.isNotEmpty && startIndex > 0) {
      prevClose = allPoints[startIndex - 1].close;
    } else {
      prevClose = p.open;
    }
    final changeVal = p.close - prevClose;
    final changePercent = (changeVal / prevClose) * 100;
    final color = changeVal >= 0 ? upColor : downColor;

    // Data tooltip
    final textStyle = const TextStyle(color: Colors.white, fontSize: 10);
    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: "${p.time}\n",
            style: textStyle.copyWith(color: Colors.white60, fontSize: 9),
          ),
          TextSpan(text: "价格: ${p.close.toStringAsFixed(2)}  "),
          TextSpan(
            text:
                "${changeVal >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%\n",
            style: textStyle.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text:
                "高: ${p.high.toStringAsFixed(2)}  低: ${p.low.toStringAsFixed(2)}",
            style: textStyle.copyWith(color: Colors.white70, fontSize: 9),
          ),
        ],
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    double tooltipX = x + 10;
    if (tooltipX + textPainter.width > size.width) {
      tooltipX = x - textPainter.width - 10;
    }
    double tooltipY = y - textPainter.height - 10;
    if (tooltipY < 0) {
      tooltipY = y + 10;
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          tooltipX - 8,
          tooltipY - 8,
          textPainter.width + 16,
          textPainter.height + 16,
        ),
        const Radius.circular(8),
      ),
      Paint()
        ..color = const Color(0xCC1A1A1A)
        ..style = PaintingStyle.fill,
    );
    textPainter.paint(canvas, Offset(tooltipX, tooltipY));
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    // Horizontal grid lines
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Vertical grid lines
    for (int i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  void _drawMALine(
    Canvas canvas,
    List<double?> maList,
    int startIndex,
    int count,
    double widthPerPoint,
    Size size,
    double minVal,
    double range,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool started = false;

    for (int i = 0; i < count; i++) {
      final index = startIndex + i;
      if (index >= maList.length) break;
      final val = maList[index];
      if (val == null) continue;

      final x = i * widthPerPoint + widthPerPoint / 2;
      final y = size.height - ((val - minVal) / range * size.height);

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    if (started) {
      canvas.drawPath(path, paint);
    }
  }

  List<double?> _calculateMA(List<KLinePoint> points, int period) {
    if (points.isEmpty) return [];
    final List<double?> result = List.filled(points.length, null);

    for (int i = 0; i < points.length; i++) {
      if (i < period - 1) continue;
      double sum = 0;
      for (int j = 0; j < period; j++) {
        sum += points[i - j].close;
      }
      result[i] = sum / period;
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant MiniKLinePainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.stock != stock;
  }

  void _drawVolumeItem(
    Canvas canvas,
    Size size,
    KLinePoint p,
    int index,
    int totalCount,
    double widthPerPoint,
    double prevClose,
  ) {
    // Volume area is bottom 15%
    final double volHeight = size.height * 0.15;
    final double volBase = size.height;

    final paint = Paint()
      ..color = (p.close >= prevClose ? upColor : downColor).withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final double barWidth = widthPerPoint * 0.7;
    final double x = index * widthPerPoint + widthPerPoint / 2;

    // Fake scaling for now, ideally find max volume in displayPoints
    final double barHeight = (p.volume / 1000000).clamp(2.0, volHeight);

    canvas.drawRect(
      Rect.fromLTRB(
        x - barWidth / 2,
        volBase - barHeight,
        x + barWidth / 2,
        volBase,
      ),
      paint,
    );
  }
}

class _KLineInteractiveContainer extends StatefulWidget {
  final StockInfo stock;
  final bool isFullScreen;

  const _KLineInteractiveContainer({
    required this.stock,
    this.isFullScreen = false,
  });

  @override
  State<_KLineInteractiveContainer> createState() =>
      _KLineInteractiveContainerState();
}

class _KLineInteractiveContainerState
    extends State<_KLineInteractiveContainer> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) =>
              _handleTouch(details.localPosition, containerSize),
          onPanUpdate: (details) =>
              _handleTouch(details.localPosition, containerSize),
          onTapDown: (details) =>
              _handleTouch(details.localPosition, containerSize),
          onDoubleTap: () => setState(() => _selectedIndex = null),
          child: Stack(
            children: [
              CustomPaint(
                painter: MiniKLinePainter(
                  widget.stock,
                  selectedIndex: _selectedIndex,
                  showVolume: widget.isFullScreen,
                ),
                size: Size.infinite,
              ),
              if (!widget.isFullScreen)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              StockKLineFullScreenPage(stock: widget.stock),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.fullscreen_rounded,
                        color: Colors.white.withOpacity(0.6),
                        size: 22,
                      ),
                    ),
                  ),
                ),
              // Clear hint
              if (_selectedIndex != null)
                Positioned(
                  bottom: 5,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "双击图表清除准星",
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleTouch(Offset localPosition, Size size) {
    // Re-synthesize to find correct index count
    final points = widget.stock.kLines;
    List<KLinePoint> displayPoints = points.length > 50
        ? points.sublist(points.length - 50)
        : List.from(points);

    final todayStr = DateTime.now()
        .toString()
        .split(' ')[0]
        .replaceAll('-', '');
    bool hasToday =
        displayPoints.isNotEmpty &&
        (displayPoints.last.time.replaceAll('-', '') == todayStr ||
            displayPoints.last.time == widget.stock.date);

    if (!hasToday && widget.stock.current > 0) {
      displayPoints.add(
        KLinePoint(time: "今日", open: 0, close: 0, high: 0, low: 0, volume: 0),
      );
    }
    if (displayPoints.isEmpty) return;

    final widthPerPoint = size.width / displayPoints.length;
    int index = (localPosition.dx / widthPerPoint).floor();
    index = index.clamp(0, displayPoints.length - 1);

    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }
}

class FavoritesListPage extends StatefulWidget {
  const FavoritesListPage({super.key});

  @override
  State<FavoritesListPage> createState() => _FavoritesListPageState();
}

class _FavoritesListPageState extends State<FavoritesListPage> {
  Timer? _refreshTimer;
  Map<String, double> _currentPrices = {};

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final now = DateTime.now();
      if (now.isMarketOpen) {
        _fetchCurrentPrices();
      } else {
        // If closed, only refresh every 5 minutes (approx 30 * 10s)
        // Use minute check to avoid fetching 30 times in one hour
        if (now.minute % 5 == 0 && now.second < 10) {
          _fetchCurrentPrices();
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchCurrentPrices();
    _startPolling();
  }

  Future<void> _fetchCurrentPrices() async {
    final symbols = stockService.favorites
        .map((f) => f.snapshot.symbol)
        .toList();
    if (symbols.isEmpty) return;
    final stocks = await stockService.fetchStocks(symbols);
    if (!mounted) return;
    setState(() {
      for (var s in stocks) {
        _currentPrices[s.symbol] = s.current;
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = stockService.favorites;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          '智能收藏与跟踪',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),
        child: favorites.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.only(
                  top: 120,
                  left: 16,
                  right: 16,
                  bottom: 30,
                ),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final fav = favorites[favorites.length - 1 - index];
                  return Dismissible(
                    key: Key(fav.id),
                    direction: DismissDirection.endToStart,

                    onDismissed: (direction) {
                      stockService.removeFavorite(fav.id);
                      setState(() {});
                      SmartDialog.showToast("${fav.snapshot.name} 已移除");
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                    ),
                    child: _buildFavoriteCard(fav),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_border_rounded, color: Colors.white10, size: 80),
          const SizedBox(height: 20),
          const Text(
            "暂无收藏建议",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "快去扫描引擎中收藏你感兴趣的股票吧",
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(FavoriteRecommendation fav) {
    final currentPrice =
        _currentPrices[fav.snapshot.symbol] ?? fav.snapshot.current;
    final pnl =
        (currentPrice - fav.snapshot.current) / fav.snapshot.current * 100;
    final pnlColor = pnl >= 0 ? Colors.redAccent : Colors.greenAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecommendationComparisonPage(
                favorite: fav,
                currentPrice: currentPrice,
              ),
            ),
          );
          if (result == true) {
            setState(() {});
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fav.snapshot.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        fav.snapshot.symbol.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: pnlColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${pnl >= 0 ? "+" : ""}${pnl.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: pnlColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (fav.suggestion.sellTarget != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "目标: ${fav.suggestion.sellTarget!.toStringAsFixed(2)}",
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildPriceInfo("推荐时", fav.snapshot.current),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white10,
                    size: 16,
                  ),
                  const Spacer(),
                  _buildPriceInfo("当前价", currentPrice, color: pnlColor),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Colors.white10, height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "建议：${fav.suggestion.action.labelCn}",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    "加入时间：${fav.capturedAt.year}-${fav.capturedAt.month}-${fav.capturedAt.day}",
                    style: const TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceInfo(String label, double price, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          price.toStringAsFixed(2),
          style: TextStyle(
            color: color ?? Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier',
          ),
        ),
      ],
    );
  }
}

class RecommendationComparisonPage extends StatefulWidget {
  final FavoriteRecommendation favorite;
  final double currentPrice;

  const RecommendationComparisonPage({
    super.key,
    required this.favorite,
    required this.currentPrice,
  });

  @override
  State<RecommendationComparisonPage> createState() =>
      _RecommendationComparisonPageState();
}

class _RecommendationComparisonPageState
    extends State<RecommendationComparisonPage> {
  late StockInfo _latestStock;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Initialize with snapshot, but override price with passed currentPrice for immediate feedback
    _latestStock = widget.favorite.snapshot.copyWith(
      current: widget.currentPrice,
    );
    _startPolling();
  }

  void _startPolling() {
    _fetchLatest(); // Initial fetch
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      final now = DateTime.now();
      if (now.isMarketOpen) {
        _fetchLatest();
      } else {
        // If closed, only refresh every 5 minutes (approx 50 * 6s)
        if (now.minute % 5 == 0 && now.second < 6) {
          _fetchLatest();
        }
      }
    });
  }

  Future<void> _fetchLatest() async {
    try {
      if (!mounted) return;
      // Fetch latest including detailed indicators if possible
      final stocks = await stockService.fetchStocks([
        widget.favorite.snapshot.symbol,
      ]);
      if (stocks.isNotEmpty && mounted) {
        // Optionally enrich with k-lines if we want detailed comparision
        // var detailed = await stockService.enrichWithIndicators(stocks.first);
        setState(() {
          _latestStock = stocks.first;
        });
      }
    } catch (e) {
      debugPrint("Error polling stock: $e");
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.favorite.snapshot;
    final pnl =
        (_latestStock.current - snapshot.current) / snapshot.current * 100;
    final pnlColor = pnl >= 0 ? Colors.redAccent : Colors.greenAccent;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          '历史与实时对比',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F2027),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () async {
              if (!context.mounted) return;
              await showCupertinoDialog(
                context: context,
                builder: (ctx) {
                  return CupertinoAlertDialog(
                    title: const Text('确认移除'),
                    content: Text('确定要移除 ${snapshot.name} 吗？'),
                    actions: [
                      CupertinoDialogAction(
                        child: const Text('取消'),
                        onPressed: () => Navigator.pop(context),
                      ),
                      CupertinoDialogAction(
                        child: const Text(
                          '确定',
                          style: TextStyle(color: Colors.red),
                        ),
                        onPressed: () {
                          context.read<FavoritesBloc>().add(
                            RemoveFavorite(widget.favorite.id),
                          );
                          Navigator.pop(context, true);
                          SmartDialog.showToast("${snapshot.name} 已移除");
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 110),

              // Total PnL Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snapshot.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          snapshot.symbol.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${pnl >= 0 ? "+" : ""}${pnl.toStringAsFixed(2)}%",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: pnlColor,
                            fontFamily: "Courier",
                          ),
                        ),
                        const Text(
                          "累计收益率",
                          style: TextStyle(fontSize: 12, color: Colors.white38),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SNAPSHOT SECTION (OLD)
              _buildComparisonCard(
                title: "收藏时刻 (Snapshot)",
                time: widget.favorite.capturedAt,
                stock: snapshot,
                isLive: false,
                color: Colors.white.withOpacity(0.5),
              ),

              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Icon(
                    Icons.arrow_downward_rounded,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              ),

              // LIVE SECTION (NEW)
              _buildComparisonCard(
                title: "实时详情 (Live)",
                time: DateTime.now(),
                stock: _latestStock,
                isLive: true,
                color: Colors.cyanAccent,
              ),

              const SizedBox(height: 40),

              // Suggestion details (Static from snapshot because suggestions are historical context)
              _buildSuggestionCard(),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFF2C5364),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).padding.bottom + 20,
          top: 10,
        ),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Text(
                      "返回列表",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (context) => StockDetailSheet(
                          initialStock: _latestStock,
                          initialSuggestion: widget.favorite.suggestion,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: Colors.cyanAccent.withOpacity(0.5),
                      ),
                    ),
                    child: const Text(
                      "查看详情",
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonCard({
    required String title,
    required DateTime time,
    required StockInfo stock,
    required bool isLive,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isLive
            ? Colors.black.withOpacity(0.3)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLive
              ? Colors.cyanAccent.withOpacity(0.3)
              : Colors.white.withOpacity(0.05),
          width: isLive ? 1.5 : 1,
        ),
        boxShadow: isLive
            ? [
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isLive) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.cyanAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Text(
                "${time.hour}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}",
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontFamily: "Courier",
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDataItem(
                "价格",
                stock.current.toStringAsFixed(2),
                color: isLive
                    ? (stock.isUp ? Colors.redAccent : Colors.greenAccent)
                    : Colors.white70,
                isBig: true,
              ),
              _buildDataItem(
                "涨跌幅",
                "${stock.changePercent.toStringAsFixed(2)}%",
                color: isLive
                    ? (stock.changePercent >= 0
                          ? Colors.redAccent
                          : Colors.greenAccent)
                    : Colors.white70,
                isBig: true,
              ),
              _buildDataItem(
                "成交量",
                _formatVolume(stock.volume),
                color: Colors.white70,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatVolume(double volume) {
    // Handle invalid or negative data (common in pre-market or clearing phases)
    if (volume < 0) return "0.00";

    if (volume >= 100000000) {
      return "${(volume / 100000000).toStringAsFixed(2)}亿手";
    }
    if (volume >= 10000) {
      return "${(volume / 10000).toStringAsFixed(2)}万手";
    }
    return "${volume.toInt()}手";
  }

  Widget _buildDataItem(
    String label,
    String value, {
    Color color = Colors.white,
    bool isBig = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isBig ? 20 : 16,
            fontWeight: FontWeight.bold,
            fontFamily: "Courier",
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard() {
    final suggestion = widget.favorite.suggestion;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "当时推荐理由",
            style: TextStyle(
              color: Colors.amberAccent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            suggestion.reason,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          if (suggestion.sellTarget != null)
            Text(
              "目标价: ${suggestion.sellTarget!.toStringAsFixed(2)}",
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class StockKLineFullScreenPage extends StatefulWidget {
  final StockInfo stock;
  const StockKLineFullScreenPage({super.key, required this.stock});

  @override
  State<StockKLineFullScreenPage> createState() =>
      _StockKLineFullScreenPageState();
}

class _StockKLineFullScreenPageState extends State<StockKLineFullScreenPage> {
  late StockInfo _currentStock;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _currentStock = widget.stock;
    _startPolling();
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final now = DateTime.now();
      if (now.isMarketOpen) {
        final stocks = await stockService.fetchStocks([widget.stock.symbol]);
        if (stocks.isNotEmpty && mounted) {
          setState(() {
            _currentStock = stocks.first;
          });
        }
      } else {
        // Closed: every 5 mins
        if (now.minute % 5 == 0 && now.second < 10) {
          final stocks = await stockService.fetchStocks([widget.stock.symbol]);
          if (stocks.isNotEmpty && mounted) {
            setState(() {
              _currentStock = stocks.first;
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: Column(
          children: [
            Text(_currentStock.name, style: const TextStyle(fontSize: 16)),
            Text(
              _currentStock.symbol.toUpperCase(),
              style: const TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Price info header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentStock.current.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _currentStock.isUp
                              ? MiniKLinePainter.upColor
                              : MiniKLinePainter.downColor,
                        ),
                      ),
                      Text(
                        "${_currentStock.change >= 0 ? '+' : ''}${_currentStock.change.toStringAsFixed(2)}  ${_currentStock.changePercent.toStringAsFixed(2)}%",
                        style: TextStyle(
                          color: _currentStock.isUp
                              ? MiniKLinePainter.upColor
                              : MiniKLinePainter.downColor,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildInfoRow(
                        "最高",
                        _currentStock.high.toStringAsFixed(2),
                      ),
                      _buildInfoRow("最低", _currentStock.low.toStringAsFixed(2)),
                      _buildInfoRow(
                        "成交量",
                        "${(_currentStock.volume / 10000).toStringAsFixed(2)}万",
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10),
            // Expanded Chart
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: _KLineInteractiveContainer(
                  stock: _currentStock,
                  isFullScreen: true,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontFamily: 'Courier',
            ),
          ),
        ],
      ),
    );
  }
}

class StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => max(maxHeight, minHeight);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
