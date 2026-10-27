import 'package:flutter/material.dart';

import '../logic/wallet_rules.dart';
import '../rate.dart';
import '../theme.dart';

class RateScreen extends StatefulWidget {
  const RateScreen({super.key});

  @override
  State<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends State<RateScreen> {
  DollarRate? rate;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await fetchDollarRate();
      if (!mounted) return;
      setState(() {
        rate = result;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error =
            'Could not load the dollar rate. Check your internet connection.';
      });
    }
  }

  void retry() {
    setState(() {
      loading = true;
      error = null;
    });
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dollar rate')),
      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 48),
                    const SizedBox(height: 12),
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: retry, child: const Text('Retry')),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.currency_exchange,
                      size: 48,
                      color: hirwaGold,
                    ),
                    const SizedBox(height: 12),
                    const Text('1 US dollar'),
                    const SizedBox(height: 8),
                    Text(
                      '${formatNumber(rate!.rwfPerDollar.round())} RWF',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: hirwaNavy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Live from ExchangeRate-API\n${rate!.updated}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
