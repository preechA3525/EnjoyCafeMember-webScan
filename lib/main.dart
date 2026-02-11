import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // เชื่อมต่อกับฐานข้อมูล Enjoy Cafe ของคุณ
  await Supabase.initialize(
    url: 'https://nzokxqowtpnzlxvupcgb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im56b2t4cW93dHBuemx4dnVwY2diIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1NzM2ODEsImV4cCI6MjA4NTE0OTY4MX0.5IzhER0iaD5Zgl4-OT7bo2C-O1IpNuNcKxwr-dCpn9E',
  );
  runApp(const MaterialApp(home: MemberPortal(), debugShowCheckedModeBanner: false));
}

class MemberPortal extends StatefulWidget {
  const MemberPortal({super.key});

  @override
  State<MemberPortal> createState() => _MemberPortalState();
}

class _MemberPortalState extends State<MemberPortal> {
  final supabase = Supabase.instance.client;
  String? memberNo;

  @override
  void initState() {
    super.initState();
    // ดึงค่า 'id' จาก URL เช่น ?id=1001
    final uri = Uri.base;
    memberNo = uri.queryParameters['id'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: memberNo == null 
        ? const Center(child: Text("ไม่พบกุญแจสมาชิก (No ID)", style: TextStyle(color: Colors.white)))
        : FutureBuilder(
            // ค้นหาข้อมูลสมาชิก
            future: supabase.from('members').select().eq('member_no', memberNo!).maybeSingle(),
            builder: (context, AsyncSnapshot memberSnap) {
              if (memberSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
              }
              if (!memberSnap.hasData || memberSnap.data == null) {
                return const Center(child: Text("รหัสกุญแจไม่ถูกต้อง", style: TextStyle(color: Colors.white)));
              }

              final member = memberSnap.data;
              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(member),
                    const Divider(color: Colors.white10, height: 40),
                    _buildTransactionList(member['id']),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildHeader(Map member) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      child: Column(
        children: [
          const Text("ENJOY CAFE MEMBER", style: TextStyle(color: Colors.cyanAccent, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          Text(member['name'] ?? "ไม่ระบุชื่อ", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          Text("${member['points'] ?? 0}", style: const TextStyle(color: Colors.cyanAccent, fontSize: 80, fontWeight: FontWeight.w900)),
          const Text("คะแนนสะสมคงเหลือ", style: TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTransactionList(dynamic memberId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase.from('point_history').select().eq('member_id', memberId).order('created_at', ascending: false).limit(10),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final logs = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final amt = log['amount'] ?? 0;
            return ListTile(
              title: Text(log['detail'] ?? "รับแต้ม", style: const TextStyle(color: Colors.white70)),
              subtitle: Text(log['created_at'].toString().substring(0, 10), style: const TextStyle(color: Colors.white24)),
              trailing: Text("${amt > 0 ? '+' : ''}$amt", 
                style: TextStyle(color: amt > 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 20)),
            );
          },
        );
      },
    );
  }
}