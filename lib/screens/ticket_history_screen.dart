import 'package:flutter/material.dart';
import 'package:ulab_bus/core/logger.dart';
import 'package:ulab_bus/core/models.dart';
import 'package:ulab_bus/services/supabase_service.dart';

class TicketHistoryScreen extends StatefulWidget {
  final String studentId;

  const TicketHistoryScreen({super.key, required this.studentId});

  @override
  State<TicketHistoryScreen> createState() => _TicketHistoryScreenState();
}

class _TicketHistoryScreenState extends State<TicketHistoryScreen> {
  List<Ticket> _tickets = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    try {
      final tickets = await SupabaseService().getStudentTickets(widget.studentId);
      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Failed to load tickets', tag: 'TICKET_HISTORY', error: e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load tickets. Please try again.';
      });
    }
  }

  void _clearError() {
    setState(() {
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket History'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTickets,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _clearError();
                _loadTickets();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      )
          : _tickets.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_number, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No tickets found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Book your first ticket to get started!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadTickets,
        child: ListView.builder(
          itemCount: _tickets.length,
          itemBuilder: (context, index) {
            final ticket = _tickets[index];
            return Card(
              margin: const EdgeInsets.all(8),
              elevation: 2,
              child: ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: ticket.isUsed ? Colors.grey : Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    ticket.isUsed ? Icons.history : Icons.confirmation_number,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                title: Text(
                  'Bus ${ticket.busId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Fare: ৳${ticket.fare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Purchased: ${_formatDate(ticket.purchaseTime)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (ticket.usageTime != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Used: ${_formatDate(ticket.usageTime!)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ticket.isUsed ? Colors.grey[300] : Colors.green[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    ticket.isUsed ? 'USED' : 'ACTIVE',
                    style: TextStyle(
                      color: ticket.isUsed ? Colors.grey[700] : Colors.green[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}