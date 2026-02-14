import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://nzokxqowtpnzlxvupcgb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im56b2t4cW93dHBuemx4dnVwY2diIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1NzM2ODEsImV4cCI6MjA4NTE0OTY4MX0.5IzhER0iaD5Zgl4-OT7bo2C-O1IpNuNcKxwr-dCpn9E',
  );
  runApp(MaterialApp(
    home: const MemberPortal(), 
    debugShowCheckedModeBanner: false,
    theme: ThemeData(textTheme: GoogleFonts.itimTextTheme()),
  ));
}

class MemberPortal extends StatefulWidget {
  const MemberPortal({super.key});
  @override State<MemberPortal> createState() => _MemberPortalState();
}

class _MemberPortalState extends State<MemberPortal> {
  final supabase = Supabase.instance.client;
  String? memberNo;
  bool _isProcessing = false;
  int _currentPage = 0;
  final int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    memberNo = Uri.base.queryParameters['id'];
  }

  // --- [🚀 ฟังก์ชันแก้ไขชื่อสมาชิก] ---
  Future<void> _updateName(Map member, String newName) async {
    if (newName.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      await supabase.from('members').update({'name': newName}).eq('id', member['id']);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("✅ เปลี่ยนชื่อเรียบร้อยแล้วจ้า")));
      }
    } finally { if (mounted) setState(() => _isProcessing = false); }
  }

  // --- [🚀 ฟังก์ชันจัดการกลุ่ม] ---
  Future<void> _manageGroup(Map member, String groupName) async {
    if (groupName.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      final existing = await supabase.from('members').select('group_name').ilike('group_name', groupName).limit(1);
      await supabase.from('members').update({'group_name': groupName}).eq('id', member['id']);
      if (mounted) {
        Navigator.pop(context);
        String msg = existing.isEmpty ? "สร้างกลุ่ม '$groupName' แล้วจ้า" : "เข้าร่วมกลุ่ม '$groupName' แล้วนะ";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.green, content: Text(msg)));
      }
    } finally { if (mounted) setState(() => _isProcessing = false); }
  }

  // --- [🚀 ฟังก์ชันโอนแต้ม] ---
  Future<void> _transferPoints(Map sender, String targetNo, int amount) async {
    if (amount <= 0) return;
    setState(() => _isProcessing = true);
    try {
      final target = await supabase.from('members').select().eq('member_no', targetNo).maybeSingle();
      if (target == null || target['id'] == sender['id'] || (sender['points'] ?? 0) < amount) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ ข้อมูลไม่ถูกต้อง หรือแต้มไม่พอจ้า")));
        return;
      }
      await supabase.from('members').update({'points': sender['points'] - amount}).eq('id', sender['id']);
      await supabase.from('members').update({'points': target['points'] + amount}).eq('id', target['id']);
      await supabase.from('point_history').insert([
        {'member_id': sender['id'], 'amount': -amount, 'detail': 'โอนให้ ID:$targetNo'},
        {'member_id': target['id'], 'amount': amount, 'detail': 'รับโอนจาก ID:${sender['member_no']}'}
      ]);
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("✅ โอนแต้มสำเร็จแล้วจ้า"))); }
    } finally { if (mounted) setState(() => _isProcessing = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F6),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: memberNo == null 
              ? const Center(child: Text("☕ สแกน QR Code ก่อนนะจ๊ะ"))
              : StreamBuilder(
                  stream: supabase.from('members').stream(primaryKey: ['id']).eq('member_no', memberNo!),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
                    final member = snapshot.data!.first;
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(children: [
                        _buildHeader(member),
                        _buildPointsCard(member),
                        _buildActionButtons(member),
                        _buildHistoryList(member['id']),
                        const SizedBox(height: 40),
                      ]),
                    );
                  },
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Map member) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(50))),
      child: Column(children: [
        Image.asset('assets/logo.jpg', width: 70, height: 70, errorBuilder: (ctx, e, s) => const Icon(Icons.store, size: 50)),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.pinkAccent.withOpacity(0.3), width: 3)),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.brown.withOpacity(0.1),
            backgroundImage: member['image_url'] != null ? NetworkImage(member['image_url']) : null,
            child: member['image_url'] == null ? const Icon(Icons.account_circle, size: 80, color: Colors.brown) : null,
          ),
        ),
        const SizedBox(height: 15),
        InkWell(
          onTap: () => _showEditNameSheet(member),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(member['name'] ?? "ยินดีต้อนรับ!", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(width: 5),
              const Icon(Icons.edit, size: 18, color: Colors.brown),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          decoration: BoxDecoration(color: Colors.brown.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
          child: Text("ID: ${member['member_no']}", style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.brown)),
        ),
        if (member['group_name'] != null) Text("กลุ่ม: ${member['group_name']}", style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 18)),
      ]),
    );
  }

  Widget _buildPointsCard(Map member) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF8A80), Color(0xFFFF5252)]), borderRadius: BorderRadius.circular(35)),
      child: Column(children: [
        const Text("แต้มสะสมของคุณ", style: TextStyle(color: Colors.white, fontSize: 20)),
        FittedBox(child: Text("${member['points']}", style: const TextStyle(color: Colors.white, fontSize: 100, fontWeight: FontWeight.w900))),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showTransferSheet(member),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.redAccent, shape: const StadiumBorder()),
            icon: const Icon(Icons.send), label: const Text("โอนแต้มให้เพื่อน", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        )
      ]),
    );
  }

  Widget _buildActionButtons(Map member) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
    child: Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        onTap: () => _showGroupSheet(member),
        leading: const Icon(Icons.group_add, color: Colors.brown),
        title: Text(member['group_name'] == null ? "สร้างหรือเข้าร่วมกลุ่ม" : "จัดการกลุ่มสะสมแต้ม", style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chevron_right),
      ),
    ),
  );

  Widget _buildHistoryList(dynamic memberId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase.from('point_history').select().eq('member_id', memberId).order('created_at', ascending: false).range(_currentPage * _pageSize, (_currentPage + 1) * _pageSize - 1),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        return Column(children: [
          const Padding(padding: EdgeInsets.all(20), child: Align(alignment: Alignment.centerLeft, child: Text("🌸 ประวัติแต้มล่าสุด", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.brown)))),
          ...logs.map((log) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: Icon(log['amount'] > 0 ? Icons.add_circle : Icons.remove_circle, color: log['amount'] > 0 ? Colors.green : Colors.red),
              title: Text(log['detail'] ?? "-", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse(log['created_at']).toLocal())),
              trailing: Text("${log['amount'] > 0 ? '+' : ''}${log['amount']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          )),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              ElevatedButton(onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null, style: ElevatedButton.styleFrom(backgroundColor: Colors.brown), child: const Text("ก่อนหน้า", style: TextStyle(color: Colors.white))),
              Text("หน้า ${_currentPage + 1}"),
              ElevatedButton(onPressed: logs.length == _pageSize ? () => setState(() => _currentPage++) : null, style: ElevatedButton.styleFrom(backgroundColor: Colors.brown), child: const Text("ถัดไป", style: TextStyle(color: Colors.white))),
            ]),
          )
        ]);
      },
    );
  }

  void _showEditNameSheet(Map m) {
    final n = TextEditingController(text: m['name'] ?? "");
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))), builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 25, right: 25, top: 25), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text("✏️ แก้ไขชื่อของคุณ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 20), TextField(controller: n, decoration: const InputDecoration(labelText: "ชื่อสมาชิก", border: OutlineInputBorder())), const SizedBox(height: 25), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.brown), onPressed: () => _updateName(m, n.text), child: const Text("บันทึกชื่อ", style: TextStyle(color: Colors.white)))), const SizedBox(height: 30)])));
  }

  void _showGroupSheet(Map m) {
    final g = TextEditingController(text: m['group_name'] ?? "");
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))), builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 25, right: 25, top: 25), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text("👥 ชื่อกลุ่มสะสมแต้ม", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 20), TextField(controller: g, decoration: const InputDecoration(labelText: "ชื่อกลุ่ม", border: OutlineInputBorder())), const SizedBox(height: 25), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.brown), onPressed: () => _manageGroup(m, g.text), child: const Text("ตกลงจ้า", style: TextStyle(color: Colors.white)))), const SizedBox(height: 30)])));
  }

  void _showTransferSheet(Map m) {
    final t = TextEditingController(), a = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))), builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 25, right: 25, top: 25), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text("🔄 โอนแต้ม", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 20), TextField(controller: t, decoration: const InputDecoration(labelText: "ID ผู้รับ", border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: a, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "จำนวนแต้ม", border: OutlineInputBorder())), const SizedBox(height: 25), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent), onPressed: () => _transferPoints(m, t.text, int.tryParse(a.text) ?? 0), child: const Text("ยืนยันการโอน", style: TextStyle(color: Colors.white)))), const SizedBox(height: 30)])));
  }
}