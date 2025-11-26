import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DebugScreen extends StatefulWidget {
  final String studentId;
  const DebugScreen({super.key, required this.studentId});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("System Diagnostic"), backgroundColor: Colors.red),
      body: Column(
        children: [
          // 1. TICKET DIAGNOSTIC
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("1. MY LATEST TICKET", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 1,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase.from('tickets')
                  .stream(primaryKey: ['id'])
                  .eq('student_id', widget.studentId)
                  .order('purchase_time', ascending: false)
                  .limit(1),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red));
                if (!snapshot.hasData) return const CircularProgressIndicator();

                final data = snapshot.data!;
                if (data.isEmpty) return const Text("Result: NO TICKETS FOUND (Check RLS Policies?)", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold));

                final ticket = data.first;
                return Container(
                  width: double.infinity,
                  color: Colors.green[100],
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Bus ID: '${ticket['bus_id']}'"),
                      Text("Is Used: ${ticket['is_used']}"),
                      Text("Purchase Time: ${ticket['purchase_time']}"),
                      const Divider(),
                      if (ticket['is_used'] == true)
                        const Text("STATUS: USED (Alerts should be BLOCKED)", style: TextStyle(color: Colors.red))
                      else
                        Text("STATUS: ACTIVE (Listening for '${ticket['bus_id']}')", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
          ),

          const Divider(thickness: 4),

          // 2. ALERT DIAGNOSTIC
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("2. INCOMING ALERTS", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase.from('alerts')
                  .stream(primaryKey: ['id'])
                  .order('timestamp', ascending: false)
                  .limit(5),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text("Error: ${snapshot.error}");
                if (!snapshot.hasData) return const CircularProgressIndicator();

                final alerts = snapshot.data!;
                if (alerts.isEmpty) return const Text("No alerts in database.");

                return ListView.builder(
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    return Card(
                      child: ListTile(
                        title: Text("Alert Bus ID: '${alert['bus_id']}'"),
                        subtitle: Text("Msg: ${alert['message']}"),
                        trailing: Text(alert['alert_type']),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}