import 'dart:async';

import 'package:finport/features/movements/data/repositories/movement_repository.dart';
import 'package:finport/features/movements/domain/entities/movement.dart';
import 'package:finport/features/movements/presentation/pages/month_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _movementRepo = MovementRepository();
  late final PageController _pageCtrl;
  Timer? _monthWatcher;
  DateTime _lastObservedNow = DateTime.now();
  List<DateTime> _visibleMonths = const [];
  bool _loadingMonths = true;
  int _currentPageIndex = 0;

  bool get _isOnCurrentMonth {
    if (_visibleMonths.isEmpty) return true;
    if (_currentPageIndex < 0 || _currentPageIndex >= _visibleMonths.length) {
      return true;
    }

    final now = DateTime.now();
    final visible = _visibleMonths[_currentPageIndex];
    return visible.month == now.month && visible.year == now.year;
  }

  void _goToCurrentMonth() {
    final now = DateTime.now();
    final currentIndex = _visibleMonths.indexWhere(
      (d) => d.month == now.month && d.year == now.year,
    );

    if (currentIndex < 0 || !_pageCtrl.hasClients) {
      _loadVisibleMonths(jumpToCurrentMonth: true);
      return;
    }

    _pageCtrl.animateToPage(
      currentIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: 0);
    _loadVisibleMonths(jumpToCurrentMonth: true);
    _monthWatcher = Timer.periodic(const Duration(minutes: 1), (_) {
      final now = DateTime.now();
      final changedMonth =
          now.month != _lastObservedNow.month ||
          now.year != _lastObservedNow.year;
      if (changedMonth) {
        _lastObservedNow = now;
        _loadVisibleMonths(jumpToCurrentMonth: true);
      }
    });
  }

  @override
  void dispose() {
    _monthWatcher?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVisibleMonths({bool jumpToCurrentMonth = false}) async {
    final previouslyVisibleMonth =
        _visibleMonths.isNotEmpty &&
            _currentPageIndex >= 0 &&
            _currentPageIndex < _visibleMonths.length
        ? _visibleMonths[_currentPageIndex]
        : null;

    setState(() => _loadingMonths = true);
    try {
      final now = DateTime.now();
      final all = await _movementRepo.listAll();
      final installments = all.where((m) => m.isInstallmentPurchase);

      final hasFutureYearInstallment = installments.any(
        (m) => m.year > now.year,
      );
      final latestInstallment = installments.fold<Movement?>(null, (latest, m) {
        if (latest == null) return m;
        final latestKey = latest.year * 100 + latest.month;
        final currentKey = m.year * 100 + m.month;
        return currentKey > latestKey ? m : latest;
      });

      final endYear = hasFutureYearInstallment
          ? (latestInstallment?.year ?? now.year)
          : now.year;
      final endMonth = hasFutureYearInstallment
          ? (latestInstallment?.month ?? 12)
          : 12;

      final generated = <DateTime>[];
      var cursor = DateTime(now.year, 1);
      final endDate = DateTime(endYear, endMonth);
      while (!cursor.isAfter(endDate)) {
        generated.add(cursor);
        cursor = DateTime(cursor.year, cursor.month + 1);
      }

      if (!mounted) return;
      setState(() {
        _visibleMonths = generated;
      });

      if (_visibleMonths.isNotEmpty) {
        int safeIndex;
        if (jumpToCurrentMonth) {
          final currentIndex = _visibleMonths.indexWhere(
            (d) => d.month == now.month && d.year == now.year,
          );
          safeIndex = currentIndex >= 0 ? currentIndex : 0;
        } else if (previouslyVisibleMonth != null) {
          final previousIndex = _visibleMonths.indexWhere(
            (d) =>
                d.month == previouslyVisibleMonth.month &&
                d.year == previouslyVisibleMonth.year,
          );
          safeIndex = previousIndex >= 0
              ? previousIndex
              : _currentPageIndex.clamp(0, _visibleMonths.length - 1);
        } else {
          safeIndex = _currentPageIndex.clamp(0, _visibleMonths.length - 1);
        }

        if (mounted) {
          setState(() => _currentPageIndex = safeIndex);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pageCtrl.hasClients) return;
          _pageCtrl.jumpToPage(safeIndex);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingMonths = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Finport',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loadingMonths
          ? const Center(child: CircularProgressIndicator())
          : PageView.builder(
              controller: _pageCtrl,
              onPageChanged: (index) {
                setState(() => _currentPageIndex = index);
              },
              itemCount: _visibleMonths.length,
              itemBuilder: (context, index) {
                final date = _visibleMonths[index];
                return MonthPage(
                  key: ValueKey('${date.year}-${date.month}'),
                  month: date.month,
                  year: date.year,
                  forceShowForm:
                      date.month == now.month && date.year == now.year,
                  onCreated: () => _loadVisibleMonths(jumpToCurrentMonth: true),
                  onDataChanged: () => _loadVisibleMonths(),
                );
              },
            ),
      bottomNavigationBar: _isOnCurrentMonth
          ? null
          : BottomAppBar(
              child: SizedBox(
                height: 60,
                child: InkWell(
                  onTap: _goToCurrentMonth,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home),
                      SizedBox(height: 2),
                      Text('Home'),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
