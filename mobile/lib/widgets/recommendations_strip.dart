import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recommendation.dart';
import '../screens/customer/item_detail_screen.dart';
import '../services/api_client.dart';
import '../state/cart_state.dart';
import '../util/money.dart';
import 'menu_image.dart';

/// "You might also like" strip for the cart screen.
///
/// Fetches suggestions for the current cart from the backend's local LLM,
/// which takes tens of seconds — so the fetch is debounced after cart
/// changes, stale responses are dropped, and the loading state stays quiet.
/// Any failure simply collapses the strip; ordering never depends on it.
class RecommendationsStrip extends StatefulWidget {
  const RecommendationsStrip({super.key});

  @override
  State<RecommendationsStrip> createState() => _RecommendationsStripState();
}

class _RecommendationsStripState extends State<RecommendationsStrip> {
  static const _debounce = Duration(milliseconds: 600);

  Timer? _timer;
  int _generation = 0;
  String _fingerprint = '';
  List<Suggestion>? _suggestions; // null while fetching

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final fingerprint = cart.lines.map((l) => l.item.id).join(',');
    if (fingerprint != _fingerprint) {
      _fingerprint = fingerprint;
      WidgetsBinding.instance.addPostFrameCallback((_) => _schedule());
    }
    if (cart.isEmpty) return const SizedBox.shrink();

    final suggestions = _suggestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 16,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text('You might also like',
                style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 148,
          child: suggestions == null ? _loadingCard() : _list(suggestions),
        ),
      ],
    );
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(_debounce, _fetch);
  }

  Future<void> _fetch() async {
    final cart = context.read<CartState>();
    if (cart.isEmpty || !mounted) return;
    final gen = ++_generation;
    setState(() => _suggestions = null);
    try {
      final result =
          await context.read<ApiClient>().fetchRecommendations(cart.lines);
      if (!mounted || gen != _generation) return;
      setState(() => _suggestions = result);
    } catch (_) {
      if (!mounted || gen != _generation) return;
      setState(() => _suggestions = []); // hide silently on failure
    }
  }

  Widget _loadingCard() {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 8),
            Text('Thinking…', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Suggestion> suggestions) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: suggestions.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, i) => _card(suggestions[i]),
    );
  }

  Widget _card(Suggestion s) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _add(s),
        child: SizedBox(
          width: 240,
          child: Row(
            children: [
              MenuImage(url: s.item.imageUrl, width: 84, height: double.infinity),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Expanded(
                        child: Text(
                          s.reason.isEmpty ? 'Goes well with your order' : s.reason,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(formatMoney(s.unitPrice)),
                          Icon(Icons.add_circle,
                              size: 22,
                              color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _add(Suggestion s) async {
    final cart = context.read<CartState>();
    final messenger = ScaffoldMessenger.of(context);
    // Required multi-choice groups have no obvious default — let staff pick.
    if (!s.safeToAutopick) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ItemDetailScreen(item: s.item)));
      return;
    }
    cart.add(s.item, List.of(s.defaultOptions), 1);
    messenger.showSnackBar(SnackBar(content: Text('${s.item.name} added')));
  }
}
