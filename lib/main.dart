import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

/* ============================================================
   COLORES (mismos tokens que el prototipo React)
   ============================================================ */
const bgDark = Color(0xFF0D1321);
const surface = Color(0xFF182137);
const accentGold = Color(0xFFE8A33D);
const accentTeal = Color(0xFF3FBF9F);
const accentCoral = Color(0xFFE8615A);
const textPrimary = Color(0xFFF4F6FB);
const textMuted = Color(0xFF93A0BF);

const List<String> diasSemana = [
  'domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'
];
const List<String> mesesAnio = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
  'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
];

String pad2(int n) => n.toString().padLeft(2, '0');
String dateKeyOf(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String formatTime12(String hhmm) {
  final parts = hhmm.split(':');
  int h = int.parse(parts[0]);
  final m = parts[1];
  final suffix = h >= 12 ? 'p. m.' : 'a. m.';
  h = h % 12;
  if (h == 0) h = 12;
  return '$h:$m $suffix';
}

/* ============================================================
   MODELO
   ============================================================ */
class Appointment {
  final String id;
  final String dateKey; // yyyy-MM-dd
  final String time; // HH:mm (24h)
  final String title;
  final String category; // cita | examen | medicamento
  final String notes; // dirección, médico, o cualquier detalle adicional

  Appointment({
    required this.id,
    required this.dateKey,
    required this.time,
    required this.title,
    required this.category,
    this.notes = '',
  });

  Appointment copyWith({
    String? dateKey,
    String? time,
    String? title,
    String? category,
    String? notes,
  }) =>
      Appointment(
        id: id,
        dateKey: dateKey ?? this.dateKey,
        time: time ?? this.time,
        title: title ?? this.title,
        category: category ?? this.category,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateKey': dateKey,
        'time': time,
        'title': title,
        'category': category,
        'notes': notes,
      };

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'],
        dateKey: j['dateKey'],
        time: j['time'],
        title: j['title'],
        category: j['category'],
        notes: j['notes'] ?? '',
      );

  IconData get icon {
    switch (category) {
      case 'examen':
        return Icons.monitor_heart_outlined;
      case 'medicamento':
        return Icons.medication_outlined;
      default:
        return Icons.medical_services_outlined;
    }
  }

  Color get color {
    switch (category) {
      case 'examen':
        return accentTeal;
      case 'medicamento':
        return accentCoral;
      default:
        return accentGold;
    }
  }

  String get period {
    final h = int.parse(time.split(':')[0]);
    if (h < 12) return 'Mañana';
    if (h < 18) return 'Tarde';
    return 'Noche';
  }
}

/* ============================================================
   ALMACENAMIENTO LOCAL (shared_preferences)
   ============================================================ */
class StorageService {
  static const _apptsKey = 'appointments_v1';
  static const _alarmTimeKey = 'alarm_time_v1';
  static const _alarmOnKey = 'alarm_on_v1';

  static Future<List<Appointment>> loadAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_apptsKey);
    if (raw == null) {
      final seed = seedAppointments();
      await saveAppointments(seed);
      return seed;
    }
    final list = jsonDecode(raw) as List;
    return list.map((e) => Appointment.fromJson(e)).toList();
  }

  static Future<void> saveAppointments(List<Appointment> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((a) => a.toJson()).toList());
    await prefs.setString(_apptsKey, raw);
  }

  static Future<String> loadAlarmTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_alarmTimeKey) ?? '08:00';
  }

  static Future<void> saveAlarmTime(String t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_alarmTimeKey, t);
  }

  static Future<bool> loadAlarmOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_alarmOnKey) ?? true;
  }

  static Future<void> saveAlarmOn(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alarmOnKey, v);
  }

  /// Datos de ejemplo la primera vez que se abre la app.
  static List<Appointment> seedAppointments() {
    final today = dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final dayAfter = today.add(const Duration(days: 2));
    return [
      Appointment(id: '1', dateKey: dateKeyOf(today), time: '09:00', title: 'Cita Lilo Dordevic', category: 'cita'),
      Appointment(id: '2', dateKey: dateKeyOf(today), time: '09:30', title: 'Electro y ECOCARDIOGRAMA', category: 'examen'),
      Appointment(id: '3', dateKey: dateKeyOf(today), time: '13:20', title: 'Cecimin dupilumab', category: 'medicamento'),
      Appointment(id: '4', dateKey: dateKeyOf(tomorrow), time: '11:00', title: 'Control general', category: 'cita'),
      Appointment(id: '5', dateKey: dateKeyOf(dayAfter), time: '16:00', title: 'Terapia física', category: 'cita'),
    ];
  }
}

/* ============================================================
   NOTIFICACIONES LOCALES
   ============================================================ */
final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await notificationsPlugin.initialize(initSettings);

  const channel = AndroidNotificationChannel(
    'agenda_alarm_channel',
    'Alarma de agenda',
    description: 'Notificación diaria con el resumen de tu agenda',
    importance: Importance.max,
  );
  await notificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> showMorningNotification() async {
  final appts = await StorageService.loadAppointments();
  final todayKey = dateKeyOf(dateOnly(DateTime.now()));
  final todays = appts.where((a) => a.dateKey == todayKey).toList()
    ..sort((a, b) => a.time.compareTo(b.time));

  final body = todays.isEmpty
      ? 'No tienes eventos programados hoy.'
      : todays.map((a) => '${formatTime12(a.time)} · ${a.title}').join('\n');

  const androidDetails = AndroidNotificationDetails(
    'agenda_alarm_channel',
    'Alarma de agenda',
    channelDescription: 'Notificación diaria con el resumen de tu agenda',
    importance: Importance.max,
    priority: Priority.high,
    styleInformation: BigTextStyleInformation(''),
    fullScreenIntent: true,
  );
  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      androidDetails.channelId,
      androidDetails.channelName,
      channelDescription: androidDetails.channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
      fullScreenIntent: true,
    ),
  );

  await notificationsPlugin.show(
    0,
    '☀️ Buenos días — tu agenda de hoy',
    todays.isEmpty ? body : '${todays.length} evento(s) programados',
    details,
  );
}

/// IMPORTANTE: esta función corre en un isolate en segundo plano.
/// Debe ser una función de nivel superior (top-level) con esta anotación,
/// tal como lo exige android_alarm_manager_plus.
@pragma('vm:entry-point')
void alarmCallbackDispatcher() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  await showMorningNotification();
}

const int dailyAlarmId = 501;

Future<void> scheduleDailyAlarm(String hhmm, bool enabled) async {
  await AndroidAlarmManager.cancel(dailyAlarmId);
  if (!enabled) return;

  final parts = hhmm.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  final now = DateTime.now();
  var firstRun = DateTime(now.year, now.month, now.day, hour, minute);
  if (firstRun.isBefore(now)) {
    firstRun = firstRun.add(const Duration(days: 1));
  }

  await AndroidAlarmManager.periodic(
    const Duration(days: 1),
    dailyAlarmId,
    alarmCallbackDispatcher,
    startAt: firstRun,
    exact: true,
    wakeup: true,
    rescheduleOnReboot: true,
  );
}

/* ============================================================
   PARSER DE COMANDOS DE VOZ EN ESPAÑOL
   (misma lógica que el prototipo web, traducida a Dart)
   ============================================================ */
class ParsedCommand {
  final String dateKey;
  final DateTime dateObj;
  final String time;
  final String title;
  final String category;
  final bool hasDate;
  final bool hasTime;

  ParsedCommand({
    required this.dateKey,
    required this.dateObj,
    required this.time,
    required this.title,
    required this.category,
    required this.hasDate,
    required this.hasTime,
  });
}

/* ============================================================
   PARSER DE ARCHIVOS .ICS (formato estándar de Google Calendar)
   Implementación propia en Dart puro, sin plugins nativos.
   Probada contra: eventos normales en UTC, eventos de todo el
   día, y eventos con zona horaria local (TZID) — los 3 formatos
   más comunes en una exportación real de Google Calendar.
   ============================================================ */
class IcsEvent {
  final String uid;
  final String title;
  final DateTime start;
  IcsEvent({required this.uid, required this.title, required this.start});
}

List<IcsEvent> parseIcsEvents(String raw) {
  // Reunifica las líneas "plegadas": RFC5545 permite cortar líneas largas
  // con un salto de línea seguido de un espacio o tabulador al inicio de
  // la siguiente — hay que revertir eso antes de leer cada propiedad.
  final rawLines = raw.replaceAll('\r\n', '\n').split('\n');
  final lines = <String>[];
  for (final line in rawLines) {
    if (line.startsWith(' ') || line.startsWith('\t')) {
      if (lines.isNotEmpty) {
        lines[lines.length - 1] = lines.last + line.substring(1);
      }
    } else {
      lines.add(line);
    }
  }

  final events = <IcsEvent>[];
  Map<String, String>? current;
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed == 'BEGIN:VEVENT') {
      current = {};
    } else if (trimmed == 'END:VEVENT') {
      if (current != null) {
        final summary = _unescapeIcsText(current['SUMMARY'] ?? 'Evento importado');
        final dtstartKey = current.keys.firstWhere(
          (k) => k == 'DTSTART' || k.startsWith('DTSTART;'),
          orElse: () => '',
        );
        if (dtstartKey.isNotEmpty) {
          final value = current[dtstartKey]!;
          final isDateOnly = dtstartKey.contains('VALUE=DATE') && !dtstartKey.contains('VALUE=DATE-TIME');
          final start = _parseIcsDate(value, isDateOnly);
          if (start != null) {
            events.add(IcsEvent(
              uid: current['UID'] ?? '$summary-$value',
              title: summary,
              start: start,
            ));
          }
        }
      }
      current = null;
    } else if (current != null) {
      final idx = line.indexOf(':');
      if (idx > 0) {
        current[line.substring(0, idx)] = line.substring(idx + 1);
      }
    }
  }
  return events;
}

DateTime? _parseIcsDate(String rawValue, bool dateOnly) {
  final value = rawValue.trim();
  try {
    if (dateOnly || value.length == 8) {
      final y = int.parse(value.substring(0, 4));
      final m = int.parse(value.substring(4, 6));
      final d = int.parse(value.substring(6, 8));
      return DateTime(y, m, d, 9, 0); // hora por defecto para eventos de todo el día
    }
    final isUtc = value.endsWith('Z');
    final clean = value.replaceAll('Z', '');
    final y = int.parse(clean.substring(0, 4));
    final m = int.parse(clean.substring(4, 6));
    final d = int.parse(clean.substring(6, 8));
    final h = int.parse(clean.substring(9, 11));
    final min = int.parse(clean.substring(11, 13));
    if (isUtc) {
      return DateTime.utc(y, m, d, h, min).toLocal();
    }
    // Sin "Z": el valor ya viene en una hora "de pared" (con TZID), la
    // tratamos como hora local del teléfono — funciona bien para el caso
    // normal de un usuario en una sola zona horaria.
    return DateTime(y, m, d, h, min);
  } catch (_) {
    return null;
  }
}

String _unescapeIcsText(String s) {
  return s
      .replaceAll('\\,', ',')
      .replaceAll('\\;', ';')
      .replaceAll('\\n', ' ')
      .replaceAll('\\N', ' ')
      .replaceAll('\\\\', '\\')
      .trim();
}

class VoiceParser {
  static ParsedCommand parse(String rawTranscript, DateTime reference) {
    final text = rawTranscript.toLowerCase().trim();
    var targetDate = dateOnly(reference);
    String? matchedDatePhrase;

    // Fecha explícita: "20 de agosto" o "el 20 de agosto de 2026".
    // La revisamos primero porque es más específica que "mañana"/"lunes".
    final explicitDateRegex = RegExp(
      r'(\d{1,2})\s+de\s+(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)(?:\s+de\s+(\d{4}))?',
      caseSensitive: false,
    );
    final explicitMatch = explicitDateRegex.firstMatch(text);

    if (explicitMatch != null) {
      final day = int.parse(explicitMatch.group(1)!);
      final monthName = explicitMatch.group(2)!.toLowerCase();
      final monthIndex = mesesAnio.indexOf(monthName) + 1;
      if (monthIndex > 0 && day >= 1 && day <= 31) {
        final year = explicitMatch.group(3) != null ? int.parse(explicitMatch.group(3)!) : reference.year;
        var candidate = DateTime(year, monthIndex, day);
        // Si no dijo el año y esa fecha ya pasó este año, asumimos el año que viene.
        if (explicitMatch.group(3) == null && candidate.isBefore(dateOnly(reference))) {
          candidate = DateTime(year + 1, monthIndex, day);
        }
        targetDate = candidate;
        matchedDatePhrase = explicitMatch.group(0);
      }
    }

    if (matchedDatePhrase == null) {
      if (text.contains('mañana') || text.contains('manana')) {
        targetDate = targetDate.add(const Duration(days: 1));
        matchedDatePhrase = text.contains('mañana') ? 'mañana' : 'manana';
      } else if (text.contains('hoy')) {
        matchedDatePhrase = 'hoy';
      } else {
        for (var i = 0; i < diasSemana.length; i++) {
          final name = diasSemana[i];
          if (text.contains(name)) {
            final todayDow = reference.weekday % 7; // domingo=0 ... sábado=6
            var diff = i - todayDow;
            if (diff <= 0) diff += 7;
            targetDate = dateOnly(reference).add(Duration(days: diff));
            matchedDatePhrase = name;
            break;
          }
        }
      }
    }

    final timeRegex = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(a\.?\s?m\.?|p\.?\s?m\.?|de la mañana|de la tarde|de la noche)?',
      caseSensitive: false,
    );
    final timeMatch = timeRegex.firstMatch(text);
    String? timeStr;
    String? matchedTimePhrase;

    if (timeMatch != null && timeMatch.group(1) != null) {
      int h = int.parse(timeMatch.group(1)!);
      final min = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
      final mod = (timeMatch.group(3) ?? '').toLowerCase();
      matchedTimePhrase = timeMatch.group(0);
      if (mod.contains('p') || mod.contains('tarde') || mod.contains('noche')) {
        if (h < 12) h += 12;
      } else if (mod.contains('a') || mod.contains('mañana')) {
        if (h == 12) h = 0;
      }
      if (h >= 0 && h <= 23 && min >= 0 && min <= 59) {
        timeStr = '${pad2(h)}:${pad2(min)}';
      }
    }

    var title = text;
    if (matchedTimePhrase != null) title = title.replaceAll(matchedTimePhrase, ' ');
    if (matchedDatePhrase != null) title = title.replaceAll(matchedDatePhrase, ' ');

    const fillers = [
      'agregar', 'añade', 'añadir', 'crear', 'poner', 'programa', 'programar',
      'agenda', 'agendar', 'recuérdame', 'recuerdame', 'recordar', 'por favor',
      'a las', 'para el', 'para', 'el día', 'el', 'de la mañana', 'de la tarde', 'de la noche'
    ];
    for (final f in fillers) {
      title = title.replaceAll(RegExp('\\b$f\\b'), ' ');
    }
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty) title = 'Nuevo evento';
    title = title[0].toUpperCase() + title.substring(1);

    var category = 'cita';
    if (RegExp(r'examen|electro|ecocardio|laboratorio|análisis').hasMatch(text)) category = 'examen';
    if (RegExp(r'medicament|pastilla|dupilumab|dosis').hasMatch(text)) category = 'medicamento';

    return ParsedCommand(
      dateKey: dateKeyOf(targetDate),
      dateObj: targetDate,
      time: timeStr ?? '09:00',
      title: title,
      category: category,
      hasDate: matchedDatePhrase != null,
      hasTime: timeStr != null,
    );
  }
}

/* ============================================================
   MAIN
   ============================================================ */
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);
  await AndroidAlarmManager.initialize();
  await initNotifications();
  await Permission.notification.request();
  runApp(const AgendaApp());
}

class AgendaApp extends StatelessWidget {
  const AgendaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agenda Inteligente',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bgDark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentGold,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

/* ============================================================
   PANTALLA PRINCIPAL
   ============================================================ */
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _centerPage = 50000;
  late final PageController _pageController =
      PageController(initialPage: _centerPage);
  late final DateTime _epochToday = dateOnly(DateTime.now());

  List<Appointment> _appointments = [];
  DateTime _selectedDate = DateTime.now();
  int _currentPage = _centerPage;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _listening = false;
  bool _handsFree = false;
  String? _micError;
  ParsedCommand? _lastAdded;
  bool _wakeToast = false;
  bool _importingCalendar = false;
  String? _importMessage;

  String _alarmTime = '08:00';
  bool _alarmOn = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = _epochToday;
    _loadData();
    _initSpeech();
  }

  Future<void> _loadData() async {
    final appts = await StorageService.loadAppointments();
    final alarmTime = await StorageService.loadAlarmTime();
    final alarmOn = await StorageService.loadAlarmOn();
    setState(() {
      _appointments = appts;
      _alarmTime = alarmTime;
      _alarmOn = alarmOn;
    });
  }

  Future<void> _initSpeech() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      setState(() => _micError =
          'Permiso de micrófono denegado. Actívalo en Ajustes > Apps > Agenda Inteligente > Permisos.');
      return;
    }
    final available = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: (err) {
        setState(() {
          _listening = false;
          _micError = 'Error de voz: ${err.errorMsg}';
        });
      },
    );
    setState(() => _speechAvailable = available);
  }

  void _onSpeechStatus(String status) {
    // Cuando el modo manos libres está activo y el reconocimiento se detiene
    // por una pausa de silencio, lo reiniciamos automáticamente.
    if (status == 'done' || status == 'notListening') {
      setState(() => _listening = false);
      if (_handsFree) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (_handsFree) _startHandsFreeListening();
        });
      }
    }
  }

  DateTime _dateForPage(int page) => _epochToday.add(Duration(days: page - _centerPage));
  int _pageForDate(DateTime d) =>
      _centerPage + dateOnly(d).difference(_epochToday).inDays;

  void _jumpToDate(DateTime d) {
    _pageController.animateToPage(
      _pageForDate(d),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  void _openAgenda() {
    _jumpToDate(_epochToday);
    setState(() => _wakeToast = true);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _wakeToast = false);
    });
  }

  /* ---------------- Comandos de voz ---------------- */

  Future<void> _handleVoiceCommand(String transcript) async {
    final parsed = VoiceParser.parse(transcript, DateTime.now());
    final newAppt = Appointment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      dateKey: parsed.dateKey,
      time: parsed.time,
      title: parsed.title,
      category: parsed.category,
    );
    final updated = [..._appointments, newAppt]
      ..sort((a, b) => (a.dateKey + a.time).compareTo(b.dateKey + b.time));
    setState(() {
      _appointments = updated;
      _lastAdded = parsed;
    });
    await StorageService.saveAppointments(updated);
    _jumpToDate(parsed.dateObj);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _lastAdded = null);
    });
  }

  Future<void> _toggleManualListen() async {
    setState(() => _micError = null);
    if (!_speechAvailable) {
      setState(() => _micError = 'El micrófono no está disponible en este dispositivo.');
      return;
    }
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    if (_handsFree) await _toggleHandsFree(); // el modo manual tiene prioridad
    setState(() => _listening = true);
    await _speech.listen(
      localeId: 'es_ES',
      listenFor: const Duration(seconds: 25),
      pauseFor: const Duration(seconds: 5),
      onResult: (SpeechRecognitionResult result) {
        if (result.finalResult) {
          _handleVoiceCommand(result.recognizedWords);
        }
      },
    );
  }

  Future<void> _toggleHandsFree() async {
    setState(() => _micError = null);
    if (!_speechAvailable) {
      setState(() => _micError = 'El micrófono no está disponible en este dispositivo.');
      return;
    }
    if (_handsFree) {
      setState(() => _handsFree = false);
      await _speech.stop();
      return;
    }
    setState(() => _handsFree = true);
    _startHandsFreeListening();
  }

  Future<void> _startHandsFreeListening() async {
    if (!_handsFree) return;
    setState(() => _listening = true);
    await _speech.listen(
      localeId: 'es_ES',
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 6),
      onResult: (SpeechRecognitionResult result) {
        if (!result.finalResult) return;
        final text = result.recognizedWords.toLowerCase();
        if (text.contains('agenda')) {
          _openAgenda();
          final rest = text.replaceAll('agenda', ' ').trim();
          if (rest.length > 3) _handleVoiceCommand(rest);
        }
      },
    );
  }

  Future<void> _showManualInputDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        title: const Text('Escribir comando', style: TextStyle(color: textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: textPrimary),
          decoration: const InputDecoration(
            hintText: 'Ej: cita mañana a las 9 am con el doctor',
            hintStyle: TextStyle(color: textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: textMuted)),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _handleVoiceCommand(controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: accentGold),
            child: const Text('Agregar', style: TextStyle(color: bgDark)),
          ),
        ],
      ),
    );
  }

  /* ---------------- Importar desde texto .ics de Google Calendar ---------------- */
  /// Recibe el TEXTO del archivo .ics (el usuario lo pega, tras abrir el
  /// archivo con un lector de texto y copiarlo) y trae sus eventos a la
  /// agenda local. No depende de ningún plugin nativo -- ni para elegir
  /// el archivo ni para leer el calendario del sistema -- así que no
  /// puede fallar por incompatibilidades de plugins con Android.
  /// Es segura de correr varias veces: no duplica eventos ya importados.
  Future<void> _importFromIcsText(String text) async {
    setState(() { _importingCalendar = true; _importMessage = null; });
    try {
      if (text.trim().isEmpty) {
        setState(() => _importingCalendar = false);
        return;
      }

      final icsEvents = parseIcsEvents(text);
      if (icsEvents.isEmpty) {
        setState(() {
          _importingCalendar = false;
          _importMessage = 'No se reconoció ningún evento en ese texto. Confirma que sea el contenido completo de un archivo .ics exportado desde Google Calendar.';
        });
        return;
      }

      final imported = icsEvents.map((ev) {
        final lower = ev.title.toLowerCase();
        var category = 'cita';
        if (RegExp(r'examen|electro|ecocardio|laboratorio|análisis').hasMatch(lower)) category = 'examen';
        if (RegExp(r'medicament|pastilla|dosis').hasMatch(lower)) category = 'medicamento';
        return Appointment(
          id: 'ics_${ev.uid}',
          dateKey: dateKeyOf(ev.start),
          time: '${pad2(ev.start.hour)}:${pad2(ev.start.minute)}',
          title: ev.title,
          category: category,
        );
      }).toList();

      final existingIds = _appointments.map((a) => a.id).toSet();
      final newOnes = imported.where((a) => !existingIds.contains(a.id)).toList();
      final merged = [..._appointments, ...newOnes]
        ..sort((a, b) => (a.dateKey + a.time).compareTo(b.dateKey + b.time));

      setState(() {
        _appointments = merged;
        _importingCalendar = false;
        _importMessage = newOnes.isEmpty
            ? 'No hay eventos nuevos por importar (ya estaban todos).'
            : 'Se importaron ${newOnes.length} evento(s) desde el archivo .ics.';
      });
      await StorageService.saveAppointments(merged);
    } catch (e) {
      setState(() {
        _importingCalendar = false;
        _importMessage = 'Error al leer el archivo: $e';
      });
    }
  }

  Future<void> _showEditApptDialog(Appointment appt) async {
    final titleController = TextEditingController(text: appt.title);
    final notesController = TextEditingController(text: appt.notes);
    String time = appt.time;
    String category = appt.category;
    DateTime date = DateTime.parse(appt.dateKey);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surface,
          title: const Text('Editar cita', style: TextStyle(color: textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    labelStyle: TextStyle(color: textMuted),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  style: const TextStyle(color: textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Notas (dirección, médico, etc.)',
                    labelStyle: TextStyle(color: textMuted),
                    hintText: 'Ej: Consultorio 302, Dr. Pérez',
                    hintStyle: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha', style: TextStyle(color: textPrimary)),
                  trailing: Text(
                    '${date.day} de ${mesesAnio[date.month - 1]} de ${date.year}',
                    style: const TextStyle(color: accentTeal, fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(date.year - 3),
                      lastDate: DateTime(date.year + 5),
                    );
                    if (picked != null) {
                      setDialogState(() => date = dateOnly(picked));
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hora', style: TextStyle(color: textPrimary)),
                  trailing: Text(formatTime12(time),
                      style: const TextStyle(color: accentGold, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    final parts = time.split(':');
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
                    );
                    if (picked != null) {
                      setDialogState(() => time = '${pad2(picked.hour)}:${pad2(picked.minute)}');
                    }
                  },
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    _categoryChip('cita', 'Cita', category, (v) => setDialogState(() => category = v)),
                    _categoryChip('examen', 'Examen', category, (v) => setDialogState(() => category = v)),
                    _categoryChip('medicamento', 'Medicamento', category, (v) => setDialogState(() => category = v)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _deleteAppt(appt);
              },
              child: const Text('Borrar', style: TextStyle(color: accentCoral)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: textMuted)),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _updateAppt(appt.copyWith(
                  title: titleController.text.trim().isEmpty ? appt.title : titleController.text.trim(),
                  notes: notesController.text.trim(),
                  time: time,
                  category: category,
                  dateKey: dateKeyOf(date),
                ));
              },
              style: FilledButton.styleFrom(backgroundColor: accentGold),
              child: const Text('Guardar', style: TextStyle(color: bgDark)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String value, String label, String selected, ValueChanged<String> onSelect) {
    final isSelected = value == selected;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelect(value),
      labelStyle: TextStyle(color: isSelected ? bgDark : textMuted, fontSize: 12),
      selectedColor: accentGold,
      backgroundColor: bgDark,
      side: BorderSide(color: isSelected ? accentGold : Colors.white12),
    );
  }

  Future<void> _updateAppt(Appointment updated) async {
    final merged = _appointments.map((a) => a.id == updated.id ? updated : a).toList()
      ..sort((a, b) => (a.dateKey + a.time).compareTo(b.dateKey + b.time));
    setState(() => _appointments = merged);
    await StorageService.saveAppointments(merged);
    if (updated.dateKey != dateKeyOf(_selectedDate)) {
      _jumpToDate(DateTime.parse(updated.dateKey));
    }
  }

  Future<void> _deleteAppt(Appointment appt) async {
    final merged = _appointments.where((a) => a.id != appt.id).toList();
    setState(() => _appointments = merged);
    await StorageService.saveAppointments(merged);
  }

  Future<void> _showIcsPasteDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        title: const Text('Pegar contenido del .ics', style: TextStyle(color: textPrimary)),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 10,
            style: const TextStyle(color: textPrimary, fontSize: 12, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              hintText: 'BEGIN:VCALENDAR\n...',
              hintStyle: TextStyle(color: textMuted),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: textMuted)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _importFromIcsText(controller.text);
            },
            style: FilledButton.styleFrom(backgroundColor: accentTeal),
            child: const Text('Importar', style: TextStyle(color: bgDark)),
          ),
        ],
      ),
    );
  }

  /* ---------------- Alarma / simulador ---------------- */

  /* ---------------- Listado de próximos eventos (rango + búsqueda) ---------------- */

  Future<void> _showUpcomingListDialog() async {
    int rangeDays = 60;
    DateTime? customStart;
    DateTime? customEnd;
    bool useCustomRange = false;
    final keywordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surface,
          title: const Text('Ver próximos eventos', style: TextStyle(color: textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rango de días', style: TextStyle(color: textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [7, 15, 30, 60, 90].map((d) {
                    final isSelected = !useCustomRange && rangeDays == d;
                    return ChoiceChip(
                      label: Text('$d días'),
                      selected: isSelected,
                      onSelected: (_) => setDialogState(() {
                        rangeDays = d;
                        useCustomRange = false;
                      }),
                      labelStyle: TextStyle(color: isSelected ? bgDark : textMuted, fontSize: 12),
                      selectedColor: accentTeal,
                      backgroundColor: bgDark,
                      side: BorderSide(color: isSelected ? accentTeal : Colors.white12),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    useCustomRange && customStart != null && customEnd != null
                        ? 'Del ${customStart!.day}/${customStart!.month} al ${customEnd!.day}/${customEnd!.month}'
                        : 'O elige un rango de fechas personalizado',
                    style: const TextStyle(color: textPrimary, fontSize: 13),
                  ),
                  trailing: const Icon(Icons.date_range, color: accentGold, size: 18),
                  onTap: () async {
                    final today = _epochToday;
                    final picked = await showDateRangePicker(
                      context: ctx,
                      firstDate: today.subtract(const Duration(days: 365)),
                      lastDate: today.add(const Duration(days: 730)),
                      initialDateRange: DateTimeRange(start: today, end: today.add(const Duration(days: 60))),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        customStart = dateOnly(picked.start);
                        customEnd = dateOnly(picked.end);
                        useCustomRange = true;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: keywordController,
                  style: const TextStyle(color: textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Buscar tipo de evento (opcional)',
                    labelStyle: TextStyle(color: textMuted),
                    hintText: 'Ej: inyección',
                    hintStyle: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: textMuted)),
            ),
            FilledButton(
              onPressed: () {
                final today = _epochToday;
                final start = useCustomRange && customStart != null ? customStart! : today;
                final end = useCustomRange && customEnd != null
                    ? customEnd!
                    : today.add(Duration(days: rangeDays));
                Navigator.pop(ctx);
                _openUpcomingListPage(start, end, keywordController.text.trim());
              },
              style: FilledButton.styleFrom(backgroundColor: accentGold),
              child: const Text('Ver listado', style: TextStyle(color: bgDark)),
            ),
          ],
        ),
      ),
    );
  }

  void _openUpcomingListPage(DateTime start, DateTime end, String keyword) {
    final startKey = dateKeyOf(start);
    final endKey = dateKeyOf(end);
    final kw = keyword.toLowerCase();
    final filtered = _appointments.where((a) {
      final inRange = a.dateKey.compareTo(startKey) >= 0 && a.dateKey.compareTo(endKey) <= 0;
      if (!inRange) return false;
      if (kw.isEmpty) return true;
      return a.title.toLowerCase().contains(kw) ||
          a.notes.toLowerCase().contains(kw) ||
          a.category.toLowerCase().contains(kw);
    }).toList()
      ..sort((a, b) => (a.dateKey + a.time).compareTo(b.dateKey + b.time));

    final Map<String, List<Appointment>> grouped = {};
    for (final a in filtered) {
      grouped.putIfAbsent(a.dateKey, () => []).add(a);
    }
    final dateKeys = grouped.keys.toList()..sort();

    Navigator.push(context, MaterialPageRoute(builder: (pageCtx) {
      return Scaffold(
        backgroundColor: bgDark,
        appBar: AppBar(
          backgroundColor: bgDark,
          elevation: 0,
          iconTheme: const IconThemeData(color: textPrimary),
          title: Text(
            keyword.isEmpty ? 'Próximos eventos' : 'Eventos: "$keyword"',
            style: const TextStyle(color: textPrimary, fontSize: 16),
          ),
        ),
        body: dateKeys.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No se encontraron eventos en ese rango.',
                      style: TextStyle(color: textMuted), textAlign: TextAlign.center),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: dateKeys.length,
                itemBuilder: (context, index) {
                  final key = dateKeys[index];
                  final date = DateTime.parse(key);
                  final dayAppts = grouped[key]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${diasSemana[date.weekday % 7][0].toUpperCase()}${diasSemana[date.weekday % 7].substring(1)}, ${date.day} de ${mesesAnio[date.month - 1]} de ${date.year}',
                          style: const TextStyle(color: accentGold, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        for (final a in dayAppts)
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.pop(pageCtx);
                              _jumpToDate(DateTime.parse(a.dateKey));
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30, height: 30,
                                    decoration: BoxDecoration(
                                        color: a.color.withOpacity(0.15), borderRadius: BorderRadius.circular(9)),
                                    child: Icon(a.icon, color: a.color, size: 15),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(a.title,
                                            style: const TextStyle(color: textPrimary, fontSize: 13),
                                            maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text(formatTime12(a.time), style: const TextStyle(color: textMuted, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      );
    }));
  }

  Future<void> _openAlarmSettings() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      isScrollControlled: true, // permite que el panel crezca y se pueda desplazar
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          // deja espacio para el teclado si llega a abrirse, y limita la
          // altura máxima para que el contenido pueda desplazarse en vez
          // de quedar cortado por debajo de la pantalla
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Alarma diaria',
                  style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _alarmOn,
                onChanged: (v) => setSheetState(() => _alarmOn = v),
                title: const Text('Activada', style: TextStyle(color: textPrimary)),
                activeColor: accentTeal,
              ),
              ListTile(
                title: const Text('Hora de despertar', style: TextStyle(color: textPrimary)),
                trailing: Text(formatTime12(_alarmTime),
                    style: const TextStyle(color: accentGold, fontWeight: FontWeight.bold)),
                onTap: () async {
                  final parts = _alarmTime.split(':');
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
                  );
                  if (picked != null) {
                    setSheetState(() => _alarmTime = '${pad2(picked.hour)}:${pad2(picked.minute)}');
                  }
                },
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await Permission.scheduleExactAlarm.request();
                  await StorageService.saveAlarmTime(_alarmTime);
                  await StorageService.saveAlarmOn(_alarmOn);
                  await scheduleDailyAlarm(_alarmTime, _alarmOn);
                  setState(() {});
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: accentGold,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.bolt, color: bgDark),
                label: const Text('Guardar y programar', style: TextStyle(color: bgDark, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await showMorningNotification();
                },
                icon: const Icon(Icons.play_arrow, color: textMuted),
                label: const Text('Probar notificación ahora', style: TextStyle(color: textMuted)),
              ),
              const Divider(height: 28, color: Colors.white10),
              const Text('Importar citas existentes',
                  style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Exporta tu Google Calendar como archivo .ics (Google Calendar → Configuración → Importar y exportar → Exportar), ábrelo con un lector de texto en el teléfono, copia todo el contenido y pégalo aquí. Es seguro repetirlo: no duplica.',
                style: TextStyle(color: textMuted, fontSize: 11),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _importingCalendar
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _showIcsPasteDialog();
                      },
                icon: _importingCalendar
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: accentTeal))
                    : const Icon(Icons.content_paste, color: accentTeal),
                label: Text(_importingCalendar ? 'Importando…' : 'Pegar contenido .ics para importar',
                    style: const TextStyle(color: accentTeal)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: accentTeal),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }

  /* ---------------- UI ---------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_handsFree) _buildHandsFreeBanner(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                    _selectedDate = _dateForPage(page);
                  });
                },
                itemBuilder: (context, index) => _buildDayView(_dateForPage(index)),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _buildFabRow(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
            icon: const Icon(Icons.chevron_left, color: textMuted),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${diasSemana[_selectedDate.weekday % 7][0].toUpperCase()}${diasSemana[_selectedDate.weekday % 7].substring(1)}, ${_selectedDate.day} de ${mesesAnio[_selectedDate.month - 1]}',
                  style: const TextStyle(color: textMuted, fontSize: 12),
                ),
                const Text('Tu agenda',
                    style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _pageController.nextPage(
                duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
            icon: const Icon(Icons.chevron_right, color: textMuted),
          ),
          IconButton(
            onPressed: _toggleHandsFree,
            icon: Icon(_handsFree ? Icons.hearing : Icons.hearing_disabled,
                color: _handsFree ? accentTeal : textMuted),
            tooltip: 'Modo manos libres: di "AGENDA"',
          ),
          IconButton(
            onPressed: _showUpcomingListDialog,
            icon: const Icon(Icons.list_alt, color: textMuted),
            tooltip: 'Ver listado de próximos eventos',
          ),
          IconButton(
            onPressed: _openAlarmSettings,
            icon: const Icon(Icons.settings, color: textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildHandsFreeBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentTeal.withOpacity(0.1),
        border: Border.all(color: accentTeal.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.hearing, color: accentTeal, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Modo manos libres activo — di "AGENDA" para abrirla, o "AGENDA cita mañana a las 9" para agendar directo.',
              style: TextStyle(color: accentTeal, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayView(DateTime date) {
    final key = dateKeyOf(date);
    final dayAppts = _appointments.where((a) => a.dateKey == key).toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    final groups = {'Mañana': <Appointment>[], 'Tarde': <Appointment>[], 'Noche': <Appointment>[]};
    for (final a in dayAppts) {
      groups[a.period]!.add(a);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
      children: [
        if (dayAppts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(
              children: const [
                Icon(Icons.calendar_today_outlined, color: textMuted, size: 32),
                SizedBox(height: 8),
                Text('No hay eventos este día.', style: TextStyle(color: textMuted)),
                SizedBox(height: 4),
                Text('Desliza o di "AGENDA" para navegar y agregar.',
                    style: TextStyle(color: textMuted, fontSize: 12)),
              ],
            ),
          ),
        for (final period in ['Mañana', 'Tarde', 'Noche'])
          if (groups[period]!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(period.toUpperCase(),
                  style: const TextStyle(
                      color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            for (final a in groups[period]!) _buildApptCard(a),
          ],
      ],
    );
  }

  Widget _buildApptCard(Appointment a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showEditApptDialog(a),
          child: Row(
        children: [
          Container(width: 5, height: 56, decoration: BoxDecoration(
            color: a.color,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
          )),
          const SizedBox(width: 12),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: a.color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(a.icon, color: a.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(a.title, style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(formatTime12(a.time), style: const TextStyle(color: textMuted, fontSize: 12)),
                  if (a.notes.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(a.notes, style: const TextStyle(color: textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
          ),
          const Icon(Icons.edit_outlined, color: textMuted, size: 16),
          const SizedBox(width: 12),
        ],
          ),
        ),
      ),
    );
  }

  Widget _buildFabRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_lastAdded != null) _buildToast(
            icon: Icons.check_circle,
            color: accentTeal,
            text: '"${_lastAdded!.title}" agregado a las ${formatTime12(_lastAdded!.time)}',
          ),
          if (_wakeToast) _buildToast(
            icon: Icons.hearing,
            color: accentTeal,
            text: 'Te escuché decir "agenda" — aquí está tu día de hoy.',
          ),
          if (_micError != null) _buildToast(
            icon: Icons.error_outline,
            color: accentCoral,
            text: _micError!,
            onClose: () => setState(() => _micError = null),
          ),
          if (_importMessage != null) _buildToast(
            icon: Icons.sync,
            color: accentTeal,
            text: _importMessage!,
            onClose: () => setState(() => _importMessage = null),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                heroTag: 'keyboard',
                mini: true,
                backgroundColor: surface,
                onPressed: _showManualInputDialog,
                child: const Icon(Icons.keyboard, color: textMuted),
              ),
              const SizedBox(width: 12),
              FloatingActionButton(
                heroTag: 'mic',
                backgroundColor: _listening ? accentCoral : accentGold,
                onPressed: _toggleManualListen,
                child: Icon(_listening ? Icons.mic_off : Icons.mic, color: bgDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToast({required IconData icon, required Color color, required String text, VoidCallback? onClose}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: textPrimary, fontSize: 12))),
          if (onClose != null)
            GestureDetector(onTap: onClose, child: const Icon(Icons.close, color: textMuted, size: 14)),
        ],
      ),
    );
  }
}
