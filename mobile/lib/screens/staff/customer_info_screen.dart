import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/cart_state.dart';
import 'take_order_screen.dart';

/// Ask for customer name before taking order on a table.
class CustomerInfoScreen extends StatefulWidget {
  final String tableNumber;
  const CustomerInfoScreen({super.key, required this.tableNumber});

  @override
  State<CustomerInfoScreen> createState() => _CustomerInfoScreenState();
}

class _CustomerInfoScreenState extends State<CustomerInfoScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _proceed() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter customer name')),
      );
      return;
    }

    // Store customer info in cart state
    context.read<CartState>().setCustomerInfo(
          name: name,
          phone: _phoneController.text.trim(),
        );

    // Navigate to menu
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TakeOrderScreen(tableNumber: widget.tableNumber),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Table ${widget.tableNumber} • Customer Info'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              'Who is this order for?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name *',
                hintText: 'e.g., John Smith',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number (optional)',
                hintText: 'e.g., +91 98765 43210',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _proceed(),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _proceed,
                child: const Text('Proceed to Menu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
