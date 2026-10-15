import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:alarm/alarm.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init();
  await Store.init();
  runApp(const AlarmApp());
}

class Tone {
  final String name;
  final String path;
  final bool builtIn;
  Tone(this.name, this.path, {this.builtIn = false});
  Map<String, dynamic> toJson() => {'name': name, 'path': path};
}

class AlarmItem {
  final int id;
  int hour;
  int minute;
  String label;
  String tonePath;
  bool enabled;
  bool repeatDaily;
  AlarmItem({required this.id, required this.hour, required this.minute, required this.label, required this.tonePath, this.enabled = true, this.repeatDaily = false});
  Map<String, dynamic> toJson() => {'id': id, 'hour': hour, 'minute': minute, 'label': label, 'tonePath': tonePath, 'enabled': enabled, 'repeatDaily': repeatDaily};
  factory AlarmItem.fromJson(Map<String, dynamic> j) => AlarmItem(id: j['id'], hour: j['hour'], minute: j['minute'], label: j['label'], tonePath: j['tonePath'], enabled: j['enabled'], repeatDaily: j['repeatDaily']?? false);
}

class Store {
  static late SharedPreferences prefs;
  static List<Tone> tones = [];
  static List<AlarmItem> alarms = [];
  static late Directory tonesDir;
  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    final docs = await getApplicationDocumentsDirectory();
    tonesDir = Directory('${docs.path}/tones');
    await tonesDir.create(recursive: true);
    final builtIns = <String, List<_N>>{
      'كلاسيكي': [for (int i = 0; i < 4; i++)...[_N(1000, 0.15), _N(0, 0.1)], _N(0, 0.6)],
      'لحن هادئ': [_N(523.25, 0.3), _N(659.25, 0.3), _N(783.99, 0.3), _N(1046.5, 0.5), _N(783.99, 0.3), _N(659.25, 0.3), _N(0, 0.6)],
      'صاعد': [for (int i = 0; i < 8; i++) _N(500 + i * 120.0, 0.12), _N(0, 0.7)],
      'طوارئ': [for (int i = 0; i < 4; i++)...[_N(900, 0.25), _N(700, 0.25)], _N(0, 0.5)],
    };
    tones = [];
    int k = 0;
    for (final e in builtIns.entries) {
      final f = File('${tonesDir.path}/builtin_${k++}.wav');
      if (!await f.exists()) await f.writeAsBytes(buildWav(e.value));
      tones.add(Tone(e.key, f.path, builtIn: true));
    }
    final custom = prefs.getStringList('customTones')?? [];
    for (final s in custom) {
      final j = jsonDecode(s);
      if (await File(j['path']).exists()) tones.add(Tone(j['name'], j['path']));
    }
    final a = prefs.getStringList('alarms')?? [];
    alarms = a.map((s) => AlarmItem.fromJson(jsonDecode(s))).toList();
  }
  static Future<void> saveAlarms() => prefs.setStringList('alarms', alarms.map((e) => jsonEncode(e.toJson())).toList());
  static Future<void> saveTones() => prefs.setStringList('customTones', tones.where((t) =>!t.builtIn).map((e) => jsonEncode(e.toJson())).toList());
  static Future<Tone?> pickCustomTone() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (r == null || r.files.single.path == null) return null;
    final src = File(r.files.single.path!);
    final name = r.files.single.name;
    final dest = File('${tonesDir.path}/${DateTime.now().millisecondsSinceEpoch}_$name');
    await src.copy(dest.path);
    final tone = Tone(name.replaceAll(RegExp(r'\.[^.]+$'), ''), dest.path);
    tones.add(tone);
    await saveTones();
    return tone;
  }
}

class _N { final double f; final double d; _N(this.f, this.d); }

Uint8List buildWav(List<_N> notes, {int rate = 22050}) {
  final samples = <int>[];
  for (final n in notes) {
    final count = (n.d * rate).round();
    for (int i = 0; i < count; i++) {
      if (n.f == 0) { samples.add(0); continue; }
      final t = i / rate;
      final edge = min(i, count - i) / (rate * 0.01);
      final fade = edge > 1? 1.0 : edge;
      final v = (sin(2 * pi * n.f * t) * 0.7 + sin(2 * pi * n.f * 2 * t) * 0.2) * fade;
      samples.add((v * 32767 * 0.8).round());
    }
  }
  final data = ByteData(44 + samples.length * 2);
  void str(int o, String s) { for (int i = 0; i < s.length; i++) data.setUint8(o + i, s.codeUnitAt(i)); }
  str(0, 'RIFF'); data.setUint32(4, 36 + samples.length * 2, Endian.little); str(8, 'WAVE'); str(12, 'fmt '); data.setUint32(16, 16, Endian.little); data.setUint16(20, 1, Endian.little); data.setUint16(22, 1, Endian.little); data.setUint32(24, rate, Endian.little); data.setUint32(28, rate * 2, Endian.little); data.setUint16(32, 2, Endian.little); data.setUint16(34, 16, Endian.little); str(36, 'data'); data.setUint32(40, samples.length * 2, Endian.little);
  for (int i = 0; i < samples.length; i++) data.setInt16(44 + i * 2, samples[i], Endian.little);
  return data.buffer.asUint8List();
}

DateTime nextOccurrence(int h, int m) { final now = DateTime.now(); var t = DateTime(now.year, now.month, now.day, h, m); if (!t.isAfter(now)) t = t.add(const Duration(days: 1)); return t; }
Future<void> scheduleAlarm(AlarmItem a, {DateTime? at}) { return Alarm.set(alarmSettings: AlarmSettings(id: a.id, dateTime: at?? nextOccurrence(a.hour, a.minute), assetAudioPath: a.tonePath, loopAudio: true, vibrate: true, volume: 0.9, fadeDuration: 3.0, notificationTitle: a.label.isEmpty? 'منبه' : a.label, notificationBody: 'حان وقت المنبه', enableNotificationOnKill: true, androidFullScreenIntent: true)); }

class AlarmApp extends StatelessWidget { const AlarmApp({super.key}); @override Widget build(BuildContext context) { return MaterialApp(navigatorKey: navigatorKey, debugShowCheckedModeBanner: false, title: 'المنبه', locale: const Locale('ar'), builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!), theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, colorSchemeSeed: Colors.teal), home: const HomePage()); } }
const _days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const _months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو','يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
String fmtTime(int h, int m) { final ap = h >= 12? 'م' : 'ص'; final h12 = h % 12 == 0? 12 : h % 12; return '$h12:${m.toString().padLeft(2, '0')} $ap'; }

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState() => _HomePageState(); }
class _HomePageState extends State<HomePage> {
  Timer? _timer; StreamSubscription? _ringSub; DateTime _now = DateTime.now(); bool _ringShown = false;
  @override void initState() { super.initState(); HijriCalendar.setLocal('ar'); _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _now = DateTime.now()); }); _init(); }
  Future<void> _init() async { await Permission.notification.request(); await Permission.scheduleExactAlarm.request(); _ringSub = Alarm.ringStream.stream.listen(_onRing); for (final a in Store.alarms) { if (await Alarm.isRinging(a.id)) { _openRing(a.id); break; } } }
  void _onRing(AlarmSettings s) => _openRing(s.id);
  void _openRing(int id) { if (_ringShown) return; final idx = Store.alarms.indexWhere((e) => e.id == id); if (idx < 0) return; _ringShown = true; navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => RingScreen(item: Store.alarms[idx]))).then((_) { _ringShown = false; if (mounted) setState(() {}); }); }
  @override void dispose() { _timer?.cancel(); _ringSub?.cancel(); super.dispose(); }
  Future<void> _addAlarm() async { final item = await showModalBottomSheet<AlarmItem>(context: context, isScrollControlled: true, builder: (_) => const AddAlarmSheet()); if (item == null) return; Store.alarms.add(item); await Store.saveAlarms(); await scheduleAlarm(item); setState(() {}); }
  Future<void> _toggle(AlarmItem a, bool v) async { a.enabled = v; if (v) { await scheduleAlarm(a); } else { await Alarm.stop(a.id); } await Store.saveAlarms(); setState(() {}); }
  Future<void> _delete(AlarmItem a) async { await Alarm.stop(a.id); Store.alarms.remove(a); await Store.saveAlarms(); setState(() {}); }
  @override Widget build(BuildContext context) {
    final h = HijriCalendar.fromDate(_now); final greg = '${_days[_now.weekday - 1]}، ${_now.day} ${_months[_now.month - 1]} ${_now.year} م'; final hijri = '${h.hDay} ${h.longMonthName} ${h.hYear} هـ'; final hh = _now.hour % 12 == 0? 12 : _now.hour % 12;
    return Scaffold(appBar: AppBar(title: const Text('المنبه'), centerTitle: true), floatingActionButton: FloatingActionButton.extended(onPressed: _addAlarm, icon: const Icon(Icons.add_alarm), label: const Text('منبه جديد')), body: Column(children: [const SizedBox(height: 12), Text('$hh:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')} ${_now.hour >= 12? 'م' : 'ص'}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold), textDirection: TextDirection.ltr), const SizedBox(height: 8), Text(greg, style: const TextStyle(fontSize: 17)), const SizedBox(height: 4), Text(hijri, style: TextStyle(fontSize: 17, color: Theme.of(context).colorScheme.primary)), const Divider(height: 28), Expanded(child: Store.alarms.isEmpty? const Center(child: Text('لا توجد منبهات. اضغط "منبه جديد"')) : ListView.builder(padding: const EdgeInsets.only(bottom: 90), itemCount: Store.alarms.length, itemBuilder: (_, i) { final a = Store.alarms[i]; final toneName = Store.tones.firstWhere((t) => t.path == a.tonePath, orElse: () => Tone('نغمة', '')).name; return Dismissible(key: ValueKey(a.id), background: Container(color: Colors.red), onDismissed: (_) => _delete(a), child: ListTile(title: Text(fmtTime(a.hour, a.minute), style: const TextStyle(fontSize: 28), textDirection: TextDirection.ltr, textAlign: TextAlign.start), subtitle: Text('${a.label.isEmpty? 'منبه' : a.label} • $toneName${a.repeatDaily? ' • يوميًا' : ''}'), trailing: Switch(value: a.enabled, onChanged: (v) => _toggle(a, v)))); }))]));
  }
}

class AddAlarmSheet extends StatefulWidget { const AddAlarmSheet({super.key}); @override State<AddAlarmSheet> createState() => _AddAlarmSheetState(); }
class _AddAlarmSheetState extends State<AddAlarmSheet> {
  TimeOfDay _time = TimeOfDay.now(); final _label = TextEditingController(); late String _tonePath; bool _repeat = false;
  @override void initState() { super.initState(); _tonePath = Store.tones.first.path; }
  @override Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ListTile(leading: const Icon(Icons.access_time), title: Text(fmtTime(_time.hour, _time.minute), style: const TextStyle(fontSize: 26), textDirection: TextDirection.ltr, textAlign: TextAlign.start), subtitle: const Text('اضغط لتغيير الوقت'), onTap: () async { final t = await showTimePicker(context: context, initialTime: _time); if (t!= null) setState(() => _time = t); }),
      TextField(controller: _label, decoration: const InputDecoration(labelText: 'اسم المنبه', border: OutlineInputBorder())), const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: _tonePath, decoration: const InputDecoration(labelText: 'النغمة', border: OutlineInputBorder()), items: [for (final t in Store.tones) DropdownMenuItem(value: t.path, child: Text(t.name))], onChanged: (v) => setState(() => _tonePath = v!)), const SizedBox(height: 8),
      OutlinedButton.icon(icon: const Icon(Icons.library_music), label: const Text('إضافة نغمة من الهاتف'), onPressed: () async { final t = await Store.pickCustomTone(); if (t!= null) setState(() => _tonePath = t.path); }),
      SwitchListTile(title: const Text('تكرار يوميًا'), value: _repeat, onChanged: (v) => setState(() => _repeat = v)),
      FilledButton(onPressed: () { Navigator.pop(context, AlarmItem(id: DateTime.now().millisecondsSinceEpoch % 2147483647, hour: _time.hour, minute: _time.minute, label: _label.text.trim(), tonePath: _tonePath, repeatDaily: _repeat)); }, child: const Text('حفظ')),
    ])));
  }
}

class RingScreen extends StatelessWidget {
  final AlarmItem item; const RingScreen({super.key, required this.item});
  Future<void> _stop(BuildContext context) async { await Alarm.stop(item.id); if (item.repeatDaily) { await scheduleAlarm(item); } else { item.enabled = false; } await Store.saveAlarms(); if (context.mounted) Navigator.pop(context); }
  Future<void> _snooze(BuildContext context) async { await Alarm.stop(item.id); await scheduleAlarm(item, at: DateTime.now().add(const Duration(minutes: 10))); if (context.mounted) Navigator.pop(context); }
  @override Widget build(BuildContext context) {
    return PopScope(canPop: false, child: Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Icon(Icons.alarm, size: 90), const SizedBox(height: 16),
      Text(fmtTime(item.hour, item.minute), textAlign: TextAlign.center, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold)),
      Text(item.label.isEmpty? 'منبه' : item.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22)), const SizedBox(height: 48),
      FilledButton.tonalIcon(style: FilledButton.styleFrom(padding: const EdgeInsets.all(20)), icon: const Icon(Icons.snooze), label: const Text('غفوة 10 دقائق', style: TextStyle(fontSize: 20)), onPressed: () => _snooze(context)), const SizedBox(height: 16),
      FilledButton(style: FilledButton.styleFrom(padding: const EdgeInsets.all(20), backgroundColor: Colors.redAccent), onPressed: () => _stop(context), child: const Text('إيقاف', style: TextStyle(fontSize: 22))),
    ])))));
  }
}