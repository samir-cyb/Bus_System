import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TicketHistoryScreen extends StatefulWidget {
  final String studentId;
  const TicketHistoryScreen({super.key, required this.studentId});

  @override
  State<TicketHistoryScreen> createState() => _TicketHistoryScreenState();
}

class _TicketHistoryScreenState extends State<TicketHistoryScreen> {
  final _supabase = Supabase.instance.client;

  Future<void> _hideTicket(String ticketId) async {
    try {
      await _supabase.from('tickets').update({'is_hidden_by_student': true}).eq('id', ticketId);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ticket removed from history.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showDeleteDialog(String ticketId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Ticket?"),
        content: const Text("This will hide the ticket from your app. It will not delete the purchase record."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _hideTicket(ticketId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket History'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('tickets')
            .stream(primaryKey: ['id'])
            .eq('student_id', widget.studentId)
            .order('purchase_time', ascending: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final allTickets = snapshot.data!;
          // Filter out hidden tickets
          final tickets = allTickets.where((t) => t['is_hidden_by_student'] != true).toList();

          if (tickets.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('History is clean', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              final isUsed = ticket['is_used'] as bool;
              final date = DateTime.parse(ticket['purchase_time']);

              return Card(
                elevation: 2,
                child: ListTile(
                  onLongPress: () => _showDeleteDialog(ticket['id']), // <--- LONG PRESS HERE
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isUsed ? Colors.grey : Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(isUsed ? Icons.history : Icons.confirmation_number, color: Colors.white),
                  ),
                  title: Text('Bus ${ticket['bus_id']}'),
                  subtitle: Text(DateFormat('dd MMM yyyy, h:mm a').format(date)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(isUsed ? 'USED' : 'ACTIVE',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isUsed ? Colors.grey : Colors.green)),
                      const SizedBox(height: 4),
                      Text("৳${ticket['fare']}"),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}