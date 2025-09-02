import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Créditos',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final col = FirebaseFirestore.instance.collection('customers');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes a crédito')),
      body: StreamBuilder<QuerySnapshot>(
        stream: col.orderBy('dueDate').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Sin clientes aún'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final due = (d['dueDate'] as Timestamp).toDate();
              final amount = (d['amount'] ?? 0).toDouble();
              final status = d['status'] ?? 'on_time';
              final daysLeft = due.difference(DateTime.now()).inDays;
              Color statusColor = status == 'overdue' ? Colors.red : (status == 'due_soon' ? Colors.amber : Colors.green);
              return ListTile(
                title: Text(d['name'] ?? 'Sin nombre'),
                subtitle: Text('Vence: ${due.toLocal().toString().split(' ').first} · Tel: ${d['phone'] ?? ''}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Monto: ${amount.toStringAsFixed(2)}'),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        status == 'overdue' ? 'Vencido' : (status == 'due_soon' ? 'Por vencer (${daysLeft}d)' : 'Al día'),
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                onLongPress: () async {
                  // Marcar saldo en 0 (pagado)
                  await col.doc(docs[i].id).update({'amount': 0.0, 'status': 'on_time', 'lastPenaltyDate': null});
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marcado como pagado')));
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCustomerScreen())),
        label: const Text('Agregar'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key});
  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  int _creditDays = 7;
  final col = FirebaseFirestore.instance.collection('customers');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo cliente')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre'), validator: (v) => (v==null||v.isEmpty)?'Requerido':null),
            TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Teléfono (+58...)'), validator: (v) => (v==null||v.isEmpty)?'Requerido':null, keyboardType: TextInputType.phone),
            TextFormField(controller: _amount, decoration: const InputDecoration(labelText: 'Monto'), validator: (v) => (v==null||double.tryParse(v)==null)?'Monto inválido':null, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Crédito:'),
              const SizedBox(width: 12),
              ChoiceChip(label: const Text('7 días'), selected: _creditDays==7, onSelected: (_){ setState(()=>_creditDays=7); }),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('15 días'), selected: _creditDays==15, onSelected: (_){ setState(()=>_creditDays=15); }),
            ]),
            const Spacer(),
            SizedBox(width: double.infinity, child: FilledButton.icon(icon: const Icon(Icons.save), label: const Text('Guardar'),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final now = DateTime.now();
                  final due = now.add(Duration(days: _creditDays));
                  await col.add({
                    'name': _name.text.trim(),
                    'phone': _phone.text.trim(),
                    'amount': double.parse(_amount.text),
                    'creditDays': _creditDays,
                    'startDate': Timestamp.fromDate(now),
                    'dueDate': Timestamp.fromDate(due),
                    'status': 'on_time',
                    'lastPenaltyDate': null,
                  });
                  if (context.mounted) Navigator.pop(context);
                }
              }))),
          ]),
        ),
      ),
    );
  }
}
