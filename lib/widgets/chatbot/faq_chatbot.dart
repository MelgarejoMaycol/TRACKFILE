import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackfile/l10n/app_language.dart';
import 'package:trackfile/services/api_service.dart';
import 'package:trackfile/services/notificaciones_service.dart';

const Color _chatInk = Color(0xFF172033);
const Color _chatMuted = Color(0xFF687086);
const Color _chatSurface = Color(0xFFF6F8FC);
const Color _chatLine = Color(0xFFE4E8F2);
const Color _chatPrimary = Color(0xFF3330BE);
const Color _chatAccent = Color(0xFF16B8A6);

Color _tone(Color color, double opacity) {
  return color.withAlpha((opacity * 255).round().clamp(0, 255).toInt());
}

class FaqChatbot extends StatefulWidget {
  final String role;
  final String? userId;

  const FaqChatbot({super.key, required this.role, this.userId});

  @override
  State<FaqChatbot> createState() => _FaqChatbotState();
}

class _FaqChatbotState extends State<FaqChatbot> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocus = FocusNode();
  final List<_ChatMessage> _messages = [];
  final Map<String, _ChatMemory> _memory = {};

  bool _isOpen = false;
  bool _isTyping = false;
  bool _showShortcuts = false;
  double _mobileLauncherLeft = 16;
  double _mobileLauncherBottom = 190;
  double _desktopLauncherLeft = 22;
  double _desktopLauncherBottom = 22;
  late String _selectedSectionTitle;
  String? _lastTopic;
  String _activeNormalizedQuestion = '';
  List<_ChatAction> _pendingBotActions = const [];
  int _turnCount = 0;

  List<_FaqSection> get _sections => _faqSectionsForRole(widget.role);

  List<_FaqAnswer> get _answers =>
      _sections.expand((section) => section.questions).toList();

  String get _storageKey {
    final normalizedRole = widget.role.toLowerCase().trim();
    final normalizedUser = widget.userId?.trim().isNotEmpty == true
        ? widget.userId!.trim()
        : 'anonimo';
    return 'faq_chatbot_history_${normalizedRole}_$normalizedUser';
  }

  @override
  void initState() {
    super.initState();
    _selectedSectionTitle = _sections.first.title;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final restored = _decodeStoredMessages(prefs.getString(_storageKey));

    if (!mounted) return;

    setState(() {
      _messages
        ..clear()
        ..addAll(restored);
      _turnCount = _messages.where((message) => message.isUser).length;
      _lastTopic = _inferLastTopicFromHistory();
    });

    if (_messages.isEmpty) {
      _addGreeting(save: true);
    } else {
      unawaited(_saveHistory());
      _scrollToBottom();
    }
  }

  void _addGreeting({required bool save}) {
    setState(() {
      _messages.add(_ChatMessage.bot(context.t('chat.greeting')));
    });

    if (save) {
      unawaited(_saveHistory());
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final recent = _messages.length > 80
        ? _messages.sublist(_messages.length - 80)
        : _messages;
    await prefs.setString(
      _storageKey,
      jsonEncode(recent.map((message) => message.toJson()).toList()),
    );
  }

  List<_ChatMessage> _decodeStoredMessages(String? raw) {
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map>()
          .map((item) => _ChatMessage.fromJson(item))
          .whereType<_ChatMessage>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  String? _inferLastTopicFromHistory() {
    for (final message in _messages.reversed) {
      final topic = _detectTopic(_normalize(message.text));
      if (topic != null) return topic;
    }
    return null;
  }

  Future<void> _clearHistory() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          icon: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _tone(_chatPrimary, 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.delete_sweep_rounded, color: _chatPrimary),
          ),
          title: Text(
            context.t('chat.clearTitle'),
            textAlign: TextAlign.center,
            style: TextStyle(color: _chatInk, fontWeight: FontWeight.w800),
          ),
          content: Text(
            context.t('chat.clearMessage'),
            textAlign: TextAlign.center,
            style: TextStyle(color: _chatMuted, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: _chatMuted,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              child: Text(context.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: _chatPrimary,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              child: Text(context.t('common.clean')),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);

    if (!mounted) return;

    setState(() {
      _messages.clear();
      _isTyping = false;
    });
    _addGreeting(save: true);
    _scrollToBottom();
  }

  Future<void> _sendMessage([String? predefinedText]) async {
    final text = (predefinedText ?? _messageController.text).trim();
    if (text.isEmpty || _isTyping) return;

    _messageController.clear();

    setState(() {
      _messages.add(_ChatMessage.user(text));
      _isTyping = true;
      _showShortcuts = false;
      _pendingBotActions = const [];
    });
    unawaited(_saveHistory());
    _scrollToBottom();

    await Future<void>.delayed(const Duration(milliseconds: 360));

    if (!mounted) return;

    final answer = await _buildConversationalAnswer(text);
    final shouldRevealShortcuts = _shouldRevealShortcuts(text, answer);

    setState(() {
      _messages.add(_ChatMessage.bot(answer, actions: _pendingBotActions));
      _isTyping = false;
      _showShortcuts = shouldRevealShortcuts;
      _turnCount++;
    });

    unawaited(_saveHistory());
    _scrollToBottom();
    _composerFocus.requestFocus();
  }

  Future<String> _buildConversationalAnswer(String question) async {
    final normalized = _normalize(question);
    _activeNormalizedQuestion = normalized;
    _pendingBotActions = const [];
    final detectedTopic = _detectTopic(normalized);
    final topic =
        detectedTopic ?? (_isContextFollowUp(normalized) ? _lastTopic : null);
    final contextAnswer = _isContextFollowUp(normalized)
        ? _answerContextFollowUp(topic)
        : null;
    if (contextAnswer != null) {
      _setActions(_actionsForTopic(topic));
    }
    final liveAnswer = contextAnswer ?? await _answerWithLiveData(normalized);
    final baseAnswer = liveAnswer ?? _findAnswer(question);
    final lead = _conversationLead(normalized, topic);
    final followUp = _followUpForTopic(topic);
    final recommendation =
        liveAnswer != null && !baseAnswer.contains('Recomendacion:')
        ? _smartRecommendation()
        : '';

    _lastTopic = detectedTopic ?? topic ?? _lastTopic;

    if (baseAnswer.startsWith('No encontre una respuesta exacta')) {
      unawaited(_saveUnknownQuestion(question));
    }

    final parts = [
      if (lead.isNotEmpty) lead,
      baseAnswer,
      if (recommendation.isNotEmpty) recommendation,
      if (followUp.isNotEmpty) followUp,
    ];

    return parts.join('\n\n');
  }

  bool _isContextFollowUp(String normalized) {
    if (_lastTopic == null) return false;

    final asksLocation = _containsAny(normalized, [
      'donde',
      'donde los',
      'donde las',
      'donde lo',
      'donde la',
      'encontrar',
      'encuentro',
      'ver',
      'abrir',
      'revisar',
      'modulo',
      'seccion',
      'pantalla',
      'ir',
      'entro',
      'entrar',
      'estan',
      'esta',
      'cual',
      'cuales',
      'primero',
      'primeros',
      'muestrame',
      'mostrar',
      'lista',
      'listar',
      'esos',
      'esas',
      'y esos',
      'y esas',
      'y eso',
    ]);

    final hasReference = _containsAny(normalized, [
      'eso',
      'esos',
      'esa',
      'esas',
      'lo',
      'los',
      'la',
      'las',
      'ellos',
      'ellas',
      'ahi',
      'alli',
      'esa informacion',
      'esa info',
    ]);

    return asksLocation && (hasReference || normalized.split(' ').length <= 7);
  }

  String? _answerContextFollowUp(String? topic) {
    final memoryTopic = topic == 'recordatorios' ? 'documentos' : topic;
    final memory = memoryTopic == null ? null : _memory[memoryTopic];
    if (memory != null && memory.items.isNotEmpty) {
      if (_lastUserAskedFirst()) {
        final first = _firstRelevantItem(memoryTopic!, memory.items);
        if (first != null) {
          return 'De lo ultimo que revise, lo primero para mirar es: $first.\n\n${_locationForTopic(memoryTopic)}';
        }
      }

      if (_lastUserAskedList()) {
        final preview = _previewItems(
          memory.items,
          _labelForTopic(memoryTopic!),
        );
        return preview.isEmpty
            ? _locationForTopic(memoryTopic)
            : 'Claro. De lo ultimo que consulte, estos son los primeros: $preview.\n\n${_locationForTopic(memoryTopic)}';
      }
    }

    switch (topic) {
      case 'documentos':
      case 'recordatorios':
        return _locationForTopic('documentos');
      case 'vehiculos':
        return _locationForTopic('vehiculos');
      case 'tramites':
      case 'solicitudes':
        return _locationForTopic('tramites');
      case 'mantenimientos':
        return _locationForTopic('mantenimientos');
      case 'notificaciones':
        return _locationForTopic('notificaciones');
      case 'perfil':
        return _locationForTopic('perfil');
      case 'overview':
        return _locationForTopic('overview');
      case 'acceso':
        return 'Las opciones de acceso estan en Login: iniciar sesion, registro de empresa y recuperacion de contrasena si esta habilitada.';
      default:
        return null;
    }
  }

  bool _lastUserAskedFirst() {
    return _containsAny(_activeNormalizedQuestion, [
      'cual vence primero',
      'vence primero',
      'cual primero',
      'primero',
      'mas urgente',
      'urgente',
      'prioridad',
    ]);
  }

  bool _lastUserAskedList() {
    return _containsAny(_activeNormalizedQuestion, [
      'muestrame',
      'mostrar',
      'primeros',
      'primeras',
      'lista',
      'listar',
      'cuales',
      'y esos',
      'y esas',
      'verlos',
      'verlas',
    ]);
  }

  String? _firstRelevantItem(String topic, List<Map<String, dynamic>> items) {
    final sorted = [...items];
    if (topic == 'documentos') {
      sorted.sort((a, b) {
        final ad = _documentExpirationDate(a);
        final bd = _documentExpirationDate(b);
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    }

    if (sorted.isEmpty) return null;
    return _labelForTopic(topic)(sorted.first);
  }

  String Function(Map<String, dynamic>) _labelForTopic(String topic) {
    switch (topic) {
      case 'documentos':
      case 'recordatorios':
        return _documentLabelWithDate;
      case 'vehiculos':
        return _vehicleLabel;
      case 'mantenimientos':
        return _maintenanceLabel;
      case 'tramites':
      case 'solicitudes':
        return _requestLabel;
      case 'notificaciones':
        return (item) =>
            _text(item['titulo'] ?? item['title'] ?? item['tipo'] ?? 'Aviso');
      default:
        return _genericName;
    }
  }

  String _locationForTopic(String topic) {
    switch (topic) {
      case 'documentos':
      case 'recordatorios':
        return 'Los encuentras en Documentos. Si vienes de vencidos o proximos a vencer, revisa tambien las tarjetas de Inicio para priorizar y luego abre Documentos para ver archivo, fecha y estado activo.';
      case 'vehiculos':
        return 'Los encuentras en Vehiculos. Puedes buscar por placa y abrir cada vehiculo para revisar documentos, mantenimientos y datos asociados.';
      case 'tramites':
      case 'solicitudes':
        return 'Eso lo encuentras en Solicitudes. Desde ahi puedes crear solicitudes, ver certificados o constancias, revisar pendientes y consultar el historial.';
      case 'mantenimientos':
        return 'Los encuentras en Mantenimientos. Puedes revisar programados, sugeridos, pendientes y filtrar por vehiculo cuando aplique.';
      case 'notificaciones':
        return 'Las encuentras en Mensajes o en la campana del panel superior. Ahi puedes revisar avisos pendientes y marcar notificaciones como leidas.';
      case 'perfil':
        return 'Eso lo encuentras en Perfil. Alli puedes revisar tus datos personales, contacto y la informacion que aplica para tu cuenta.';
      case 'overview':
        return 'El resumen lo puedes contrastar en Inicio. Para detalle entra al modulo correspondiente: Documentos, Solicitudes, Mantenimientos, Vehiculos o Mensajes.';
      default:
        return 'Puedes revisarlo desde el modulo relacionado en el menu principal.';
    }
  }

  String _conversationLead(String normalized, String? topic) {
    if (_turnCount == 0 && !_containsAny(normalized, ['hola', 'buenas'])) {
      return 'Perfecto, te ayudo con eso.';
    }

    if (_lastTopic != null && topic == _lastTopic) {
      return 'Si, seguimos con ${_topicLabel(topic)}.';
    }

    if (_containsAny(normalized, ['gracias', 'listo', 'ok', 'vale'])) {
      return 'Con gusto.';
    }

    return '';
  }

  bool _shouldRevealShortcuts(String question, String answer) {
    final normalizedQuestion = _normalize(question);
    final normalizedAnswer = _normalize(answer);

    return _containsAny(normalizedQuestion, [
          'que puedes hacer',
          'que sabes hacer',
          'opciones',
          'atajos',
          'ayuda',
          'no entiendo',
          'no se',
        ]) ||
        normalizedAnswer.contains('no encontre una respuesta exacta');
  }

  Future<String?> _answerWithLiveData(String normalized) async {
    final multiIntentAnswer = await _answerMultipleLiveIntents(normalized);
    if (multiIntentAnswer != null) {
      return multiIntentAnswer;
    }

    if (_isOverviewQuestion(normalized)) {
      return await _answerOverview();
    }

    if (_isNotificationCountQuestion(normalized)) {
      return await _answerNotifications();
    }

    if (_isPersonDocumentQuestion(normalized)) {
      return await _answerPersonDocuments(normalized);
    }

    if (_isExpiredDocumentQuestion(normalized)) {
      return await _answerExpiredDocuments();
    }

    if (_isExpiringDocumentQuestion(normalized)) {
      return await _answerExpiringDocuments();
    }

    if (_isDocumentRiskSummaryQuestion(normalized)) {
      return await _answerDocumentSummary();
    }

    if (_isDocumentSummaryQuestion(normalized)) {
      return await _answerDocumentSummary();
    }

    if (_isPendingRequestQuestion(normalized)) {
      return await _answerPendingRequests();
    }

    if (_isMaintenanceCountQuestion(normalized)) {
      return await _answerMaintenanceCounts(normalized);
    }

    if (_isVehicleQuestion(normalized)) {
      return await _answerVehicles();
    }

    if (_isPeopleCountQuestion(normalized)) {
      return await _answerPeopleCounts(normalized);
    }

    if (_isRequestTypesQuestion(normalized)) {
      return await _answerRequestTypes();
    }

    if (_isMaintenanceTypesQuestion(normalized)) {
      return await _answerMaintenanceTypes();
    }

    if (_isProfileQuestion(normalized)) {
      return await _answerProfile();
    }

    return null;
  }

  Future<String?> _answerMultipleLiveIntents(String normalized) async {
    final intents = <String, Future<String> Function()>{};

    if (_isExpiredDocumentQuestion(normalized)) {
      intents['Documentos vencidos'] = _answerExpiredDocuments;
    } else if (_isExpiringDocumentQuestion(normalized)) {
      intents['Documentos por vencer'] = _answerExpiringDocuments;
    } else if (_isDocumentSummaryQuestion(normalized) ||
        _isDocumentRiskSummaryQuestion(normalized)) {
      intents['Documentos'] = _answerDocumentSummary;
    }

    if (_isMaintenanceCountQuestion(normalized)) {
      intents['Mantenimientos'] = () => _answerMaintenanceCounts(normalized);
    }

    if (_isPendingRequestQuestion(normalized)) {
      intents['Solicitudes'] = _answerPendingRequests;
    }

    if (_isNotificationCountQuestion(normalized)) {
      intents['Notificaciones'] = _answerNotifications;
    }

    if (_isVehicleQuestion(normalized)) {
      intents['Vehiculos'] = _answerVehicles;
    }

    if (intents.length < 2) return null;

    final parts = <String>[];
    for (final entry in intents.entries) {
      final answer = await entry.value();
      parts.add('${entry.key}:\n$answer');
    }

    final recommendation = _smartRecommendation();
    return [
      'Revise varias cosas a la vez:',
      ...parts,
      if (recommendation.isNotEmpty) recommendation,
    ].join('\n\n');
  }

  bool _isOverviewQuestion(String normalized) {
    return _containsAny(normalized, [
      'resumen',
      'estado general',
      'como voy',
      'que tengo pendiente',
      'que pendientes tengo',
      'pendientes generales',
      'alertas importantes',
      'que debo revisar',
    ]);
  }

  bool _isNotificationCountQuestion(String normalized) {
    return _containsAny(normalized, [
          'notificacion',
          'notificaciones',
          'mensaje',
          'mensajes',
          'aviso',
          'avisos',
          'alerta',
          'alertas',
          'campana',
        ]) &&
        _containsAny(normalized, [
          'mis',
          'tengo',
          'hay',
          'cuantas',
          'cuantos',
          'cantidad',
          'numero',
          'sin leer',
          'por leer',
          'no leidas',
          'no lei',
          'leer',
          'leido',
          'leidos',
          'nuevas',
          'recientes',
          'pendientes',
        ]);
  }

  bool _isExpiredDocumentQuestion(String normalized) {
    return _containsAny(normalized, [
          'documento',
          'documentos',
          'soat',
          'tecnomecanica',
          'licencia',
          'poliza',
        ]) &&
        _containsAny(normalized, [
          'vencido',
          'vencidos',
          'caducado',
          'caducados',
          'caducar',
          'expirado',
          'expirados',
          'expirar',
          'ya vencieron',
          'que vencieron',
        ]);
  }

  bool _isExpiringDocumentQuestion(String normalized) {
    return _containsAny(normalized, [
          'documento',
          'documentos',
          'soat',
          'tecnomecanica',
          'licencia',
          'poliza',
        ]) &&
        _containsAny(normalized, [
          'por vencer',
          'proximo a vencer',
          'proximos a vencer',
          'proximo',
          'proximos',
          'vence pronto',
          'vencen pronto',
          'van a vencer',
          'se vencen',
          'se vence',
          'por caducar',
          'por expirar',
          '30 dias',
        ]);
  }

  bool _isDocumentSummaryQuestion(String normalized) {
    return _containsAny(normalized, [
          'documento',
          'documentos',
          'soat',
          'tecnomecanica',
          'licencia',
          'poliza',
        ]) &&
        _containsAny(normalized, [
          'cuantos',
          'cuantas',
          'cantidad',
          'numero',
          'total',
          'resumen',
          'estado',
          'tengo',
          'hay',
          'mis',
        ]);
  }

  bool _isPersonDocumentQuestion(String normalized) {
    return _containsAny(normalized, [
          'documento',
          'documentos',
          'soat',
          'licencia',
          'tecnomecanica',
          'poliza',
        ]) &&
        _containsAny(normalized, [
          'persona',
          'usuario',
          'conductor',
          'propietario',
          'empleado',
          'trabajador',
          'dueno',
        ]);
  }

  bool _isDocumentRiskSummaryQuestion(String normalized) {
    return _containsAny(normalized, [
          'documento',
          'documentos',
          'soat',
          'tecnomecanica',
          'licencia',
          'poliza',
        ]) &&
        _containsAny(normalized, [
          'cuantos',
          'cuantas',
          'cantidad',
          'numero',
          'resumen',
          'estado',
          'hay',
          'tengo',
        ]) &&
        _containsAny(normalized, [
          'vencido',
          'vencidos',
          'por vencer',
          'proximos',
          'vence pronto',
          'vencen pronto',
          '30 dias',
          'caducado',
          'expirado',
        ]);
  }

  bool _isPendingRequestQuestion(String normalized) {
    return _containsAny(normalized, [
          'solicitud',
          'solicitudes',
          'certificado',
          'certificados',
          'certificacion',
          'certificaciones',
          'constancia',
          'constancias',
          'tramite',
          'tramites',
        ]) &&
        _containsAny(normalized, [
          'pendiente',
          'pendientes',
          'tengo',
          'hay',
          'abierta',
          'abiertas',
          'estado',
          'revision',
          'en revision',
          'revisar',
          'por revisar',
          'sin gestionar',
          'sin responder',
          'por responder',
          'por aprobar',
        ]);
  }

  bool _isMaintenanceCountQuestion(String normalized) {
    return _containsAny(normalized, [
          'mantenimiento',
          'mantenimientos',
          'revision',
          'revisiones',
          'preventivo',
          'preventivos',
          'correctivo',
          'correctivos',
          'taller',
        ]) &&
        _containsAny(normalized, [
          'cuantos',
          'cuantas',
          'cantidad',
          'numero',
          'tengo',
          'hay',
          'programado',
          'programados',
          'agendado',
          'agendados',
          'sugerido',
          'sugeridos',
          'recomendado',
          'recomendados',
          'pendiente',
          'pendientes',
          'por hacer',
          'por realizar',
          'hacer',
          'realizar',
        ]);
  }

  bool _isVehicleQuestion(String normalized) {
    return _containsAny(normalized, [
          'vehiculo',
          'vehiculos',
          'carro',
          'carros',
          'flota',
          'placa',
          'placas',
        ]) &&
        _containsAny(normalized, [
          'cuantos',
          'cuantas',
          'cantidad',
          'numero',
          'tengo',
          'asignado',
          'asignados',
          'mis',
          'cuales',
          'lista',
          'ver',
        ]);
  }

  bool _isPeopleCountQuestion(String normalized) {
    return _containsAny(normalized, [
          'conductor',
          'conductores',
          'propietario',
          'propietarios',
          'usuario',
          'usuarios',
          'persona',
          'personas',
        ]) &&
        _containsAny(normalized, [
          'cuantos',
          'cuantas',
          'cantidad',
          'numero',
          'hay',
          'tengo',
          'registrados',
          'registradas',
        ]);
  }

  bool _isRequestTypesQuestion(String normalized) {
    return _containsAny(normalized, [
          'solicitud',
          'solicitudes',
          'certificado',
          'certificados',
          'certificacion',
          'certificaciones',
          'constancia',
          'constancias',
          'tramite',
          'tramites',
        ]) &&
        _containsAny(normalized, [
          'puedo pedir',
          'puedo solicitar',
          'tipos',
          'opciones',
          'disponibles',
          'hacer',
          'crear',
        ]);
  }

  bool _isMaintenanceTypesQuestion(String normalized) {
    return _containsAny(normalized, [
          'mantenimiento',
          'mantenimientos',
          'revision',
          'revisiones',
        ]) &&
        _containsAny(normalized, [
          'tipos',
          'opciones',
          'disponibles',
          'puedo registrar',
          'puedo crear',
          'clases',
        ]);
  }

  bool _isProfileQuestion(String normalized) {
    return _containsAny(normalized, [
          'perfil',
          'mis datos',
          'mi informacion',
          'correo',
          'telefono',
          'direccion',
          'mi nombre',
          'quien soy',
          'empresa',
        ]) &&
        _containsAny(normalized, [
          'cual',
          'cuales',
          'ver',
          'mostrar',
          'tengo',
          'registrado',
          'registrada',
          'datos',
          'informacion',
        ]);
  }

  Future<String> _answerOverview() async {
    try {
      final results = await Future.wait<dynamic>([
        _loadDocumentsForCurrentRole(),
        NotificacionesService.contador(),
        NotificacionesService.listarNoLeidas(),
        ApiService.getSolicitudes(),
        _loadMantenimientosForCurrentRole(),
        _loadVehiclesForCurrentRole(),
      ]);

      final docs = (results[0] as List<Map<String, dynamic>>)
          .where(_isDocumentActive)
          .toList();
      final expired = docs.where(_isDocumentExpired).length;
      final expiringDocs = _documentsExpiringSoon(docs);
      final expiring = expiringDocs.length;

      final notifications = results[1] as int;
      final unreadNotifications = results[2] as List<Map<String, dynamic>>;
      final solicitudes = results[3] as List<Map<String, dynamic>>;
      final pendingRequests = solicitudes.where(_isRequestPending).length;

      final mantenimientos = results[4] as List<Map<String, dynamic>>;
      final pendingMaintenance = mantenimientos
          .where(_isMaintenancePending)
          .length;
      final vehicles = results[5] as List<Map<String, dynamic>>;

      _rememberResult(
        'documentos',
        expiringDocs.isNotEmpty
            ? expiringDocs
            : docs.where(_isDocumentExpired).toList(),
        _actionsForTopic('documentos'),
      );
      _rememberResult(
        'mantenimientos',
        mantenimientos.where(_isMaintenancePending).toList(),
        _actionsForTopic('mantenimientos'),
      );
      _rememberResult(
        'solicitudes',
        solicitudes.where(_isRequestPending).toList(),
        _actionsForTopic('solicitudes'),
      );
      _rememberResult('vehiculos', vehicles, _actionsForTopic('vehiculos'));
      _rememberResult(
        'notificaciones',
        unreadNotifications,
        _actionsForTopic('notificaciones'),
      );

      final priorities = <String>[
        if (expired > 0) 'actualizar documentos vencidos',
        if (expiring > 0)
          'preparar renovaciones de documentos que vencen pronto',
        if (pendingRequests > 0) 'responder o revisar solicitudes pendientes',
        if (pendingMaintenance > 0) 'programar mantenimientos pendientes',
        if (notifications > 0) 'leer mensajes recientes',
      ];

      final nextStep = priorities.isEmpty
          ? 'No veo alertas fuertes ahora mismo. Mantendria una revision periodica de Documentos y Mantenimientos.'
          : 'Prioridad sugerida: ${priorities.take(3).join(', ')}.';

      return 'Analice tu panel completo con los datos disponibles:\n\n'
          'Documentos: ${docs.length} activos, $expired vencido${expired == 1 ? '' : 's'} y $expiring proximo${expiring == 1 ? '' : 's'} a vencer en 30 dias.\n'
          'Notificaciones: $notifications sin leer.\n'
          'Solicitudes/certificados: $pendingRequests pendiente${pendingRequests == 1 ? '' : 's'}.\n'
          'Mantenimientos: $pendingMaintenance pendiente${pendingMaintenance == 1 ? '' : 's'}.\n'
          'Vehiculos que puedes revisar: ${vehicles.length}.\n\n'
          '$nextStep\n\n'
          '${_visibilityHint()}';
    } catch (_) {
      return 'No pude armar el resumen completo ahora mismo. Puedes preguntarme por partes: documentos vencidos, notificaciones, solicitudes pendientes, vehiculos o mantenimientos.';
    }
  }

  Future<String> _answerNotifications() async {
    try {
      final count = await NotificacionesService.contador();
      final unread = await NotificacionesService.listarNoLeidas();
      final preview = _previewItems(
        unread,
        (item) => _text(
          item['titulo'] ?? item['title'] ?? item['tipo'] ?? 'Notificacion',
        ),
      );
      _rememberResult(
        'notificaciones',
        unread,
        _actionsForTopic('notificaciones'),
      );

      if (count <= 0) {
        return 'Revise tus notificaciones y por ahora no tienes mensajes sin leer.';
      }

      return 'Tienes $count notificacion${count == 1 ? '' : 'es'} sin leer.'
          '${preview.isEmpty ? '' : '\n\nMas recientes: $preview'}'
          '\n\nPuedes revisarlas desde Mensajes o desde la campana del panel superior.';
    } catch (_) {
      return 'No pude consultar tus notificaciones en este momento. Intenta abrir Mensajes o la campana del panel superior para verificarlo.';
    }
  }

  Future<String> _answerExpiredDocuments() async {
    try {
      final docs = await _loadDocumentsForCurrentRole();
      final expired = docs.where(_isDocumentExpired).toList();
      final preview = _previewItems(expired, _documentLabel);
      _rememberResult('documentos', expired, _actionsForTopic('documentos'));

      if (expired.isEmpty) {
        return 'Revise tus documentos activos y por ahora no encontre vencimientos pendientes.';
      }

      return 'Tienes ${expired.length} documento${expired.length == 1 ? '' : 's'} vencido${expired.length == 1 ? '' : 's'}.'
          '${preview.isEmpty ? '' : '\n\nAlgunos son: $preview'}'
          '\n\nSolo estoy contando documentos activos. Te recomiendo entrar a Documentos para revisar el detalle, actualizar el archivo o corregir la fecha de vencimiento.';
    } catch (_) {
      return 'No pude consultar los documentos vencidos ahora mismo. Puedes revisarlos desde Inicio o Documentos.';
    }
  }

  Future<String> _answerExpiringDocuments() async {
    try {
      final docs = await _loadDocumentsForCurrentRole();
      final expiring = _documentsExpiringSoon(docs);

      final preview = _previewItems(expiring, (doc) {
        final date = _documentExpirationDate(doc);
        final suffix = date == null ? '' : ' (${_formatDate(date)})';
        return '${_documentLabel(doc)}$suffix';
      });
      _rememberResult('documentos', expiring, _actionsForTopic('documentos'));

      if (expiring.isEmpty) {
        return 'Revise tus documentos activos y no veo vencimientos dentro de los proximos 30 dias.';
      }

      return 'Tienes ${expiring.length} documento${expiring.length == 1 ? '' : 's'} proximo${expiring.length == 1 ? '' : 's'} a vencer en los proximos 30 dias.'
          '${preview.isEmpty ? '' : '\n\nMas cercanos: $preview'}'
          '\n\nPuedes gestionarlos desde Documentos y revisar alertas en Inicio o Mensajes.';
    } catch (_) {
      return 'No pude consultar los proximos vencimientos ahora mismo. Puedes revisarlos desde Inicio o Documentos.';
    }
  }

  Future<String> _answerDocumentSummary() async {
    try {
      final docs = (await _loadDocumentsForCurrentRole())
          .where(_isDocumentActive)
          .toList();
      final expired = docs.where(_isDocumentExpired).toList();
      final expiring = _documentsExpiringSoon(docs);
      final valid = docs.length - expired.length;
      final preview = _previewItems(expiring.isNotEmpty ? expiring : expired, (
        doc,
      ) {
        final date = _documentExpirationDate(doc);
        final suffix = date == null ? '' : ' (${_formatDate(date)})';
        return '${_documentLabel(doc)}$suffix';
      });
      _rememberResult(
        'documentos',
        expiring.isNotEmpty ? expiring : expired,
        _actionsForTopic('documentos'),
      );

      return 'Encontre ${docs.length} documento${docs.length == 1 ? '' : 's'} que puedes revisar.'
          '\n\nVencidos: ${expired.length}.'
          '\nProximos a vencer en 30 dias: ${expiring.length}.'
          '\nCon fecha vigente o sin alerta de vencimiento: ${valid < 0 ? 0 : valid}.'
          '${preview.isEmpty ? '' : '\n\nPara revisar primero: $preview'}'
          '\n\n${_visibilityHint()}';
    } catch (_) {
      return 'No pude consultar el resumen de documentos ahora mismo. Intenta preguntarme por "documentos vencidos" o revisa el modulo Documentos.';
    }
  }

  Future<String> _answerPersonDocuments(String normalized) async {
    if (await _isCompanyRole()) {
      final actions = <_ChatAction>[];
      if (_containsAny(normalized, ['conductor', 'conductores'])) {
        actions.add(
          const _ChatAction(label: 'Abrir Conductores', target: 'conductores'),
        );
      } else if (_containsAny(normalized, ['propietario', 'propietarios'])) {
        actions.add(
          const _ChatAction(
            label: 'Abrir Propietarios',
            target: 'propietarios',
          ),
        );
      } else {
        actions.addAll(const [
          _ChatAction(label: 'Abrir Conductores', target: 'conductores'),
          _ChatAction(label: 'Abrir Propietarios', target: 'propietarios'),
        ]);
      }
      actions.add(
        const _ChatAction(label: 'Abrir Documentos', target: 'documentos'),
      );
      _setActions(actions);

      return 'Para ver documentos de una persona, entra por Conductores o Propietarios, busca la persona y abre sus documentos asociados. Si necesitas revisar por tipo, fecha o estado, tambien puedes entrar directo a Documentos.';
    }

    _setActions(_actionsForTopic('documentos'));
    return 'Puedes revisar tus documentos asociados desde Documentos. Ahi aparecen tus documentos personales y los vinculados a tus vehiculos.';
  }

  Future<String> _answerPendingRequests() async {
    try {
      final solicitudes = await ApiService.getSolicitudes();
      final pending = solicitudes.where(_isRequestPending).toList();
      final preview = _previewItems(pending, _requestLabel);
      _rememberResult('tramites', pending, _actionsForTopic('tramites'));

      if (pending.isEmpty) {
        return 'Revise tus solicitudes y no veo certificados, constancias o tramites pendientes en este momento.';
      }

      return 'Tienes ${pending.length} solicitud${pending.length == 1 ? '' : 'es'} o certificado${pending.length == 1 ? '' : 's'} pendiente${pending.length == 1 ? '' : 's'}.'
          '${preview.isEmpty ? '' : '\n\nAlgunas son: $preview'}'
          '\n\nEntra a Solicitudes para ver el estado, historial y respuesta de la empresa.';
    } catch (_) {
      return 'No pude consultar tus solicitudes ahora mismo. Puedes revisarlas desde el modulo Solicitudes.';
    }
  }

  Future<String> _answerMaintenanceCounts(String normalized) async {
    try {
      final mantenimientos = await _loadMantenimientosForCurrentRole();

      final scheduled = mantenimientos.where(_isMaintenanceScheduled).toList();
      final suggested = mantenimientos.where(_isMaintenanceSuggested).toList();
      final pending = mantenimientos.where(_isMaintenancePending).toList();
      _rememberResult(
        'mantenimientos',
        pending.isNotEmpty
            ? pending
            : (scheduled.isNotEmpty ? scheduled : suggested),
        _actionsForTopic('mantenimientos'),
      );

      final asksScheduled = _containsAny(normalized, [
        'programado',
        'programados',
        'agendado',
        'agendados',
      ]);
      final asksSuggested = _containsAny(normalized, [
        'sugerido',
        'sugeridos',
        'recomendado',
        'recomendados',
      ]);
      final asksPending = _containsAny(normalized, ['pendiente', 'pendientes']);

      if ((asksScheduled && asksSuggested) ||
          (asksScheduled && asksPending) ||
          (asksSuggested && asksPending)) {
        return 'Tienes ${scheduled.length} mantenimiento${scheduled.length == 1 ? '' : 's'} programado${scheduled.length == 1 ? '' : 's'}, ${suggested.length} sugerido${suggested.length == 1 ? '' : 's'} y ${pending.length} pendiente${pending.length == 1 ? '' : 's'}.'
            '\n\n${_visibilityHint()}';
      }

      if (asksScheduled) {
        return _maintenanceAnswer('programado', scheduled);
      }

      if (asksSuggested) {
        return _maintenanceAnswer('sugerido', suggested);
      }

      if (asksPending) {
        return _maintenanceAnswer('pendiente', pending);
      }

      return 'Tienes ${scheduled.length} mantenimiento${scheduled.length == 1 ? '' : 's'} programado${scheduled.length == 1 ? '' : 's'} y ${suggested.length} sugerido${suggested.length == 1 ? '' : 's'}.'
          '\n\nPendientes en total: ${pending.length}.'
          '\n\nPuedes ver el detalle desde Mantenimientos.';
    } catch (_) {
      return 'No pude consultar tus mantenimientos ahora mismo. Puedes revisarlos desde el modulo Mantenimientos.';
    }
  }

  Future<String> _answerVehicles() async {
    try {
      final vehicles = await _loadVehiclesForCurrentRole();
      final preview = _previewItems(vehicles, _vehicleLabel);
      _rememberResult('vehiculos', vehicles, _actionsForTopic('vehiculos'));

      if (vehicles.isEmpty) {
        return 'Revise tus vehiculos y por ahora no encontre registros asociados. ${_visibilityHint()}';
      }

      return 'Tienes ${vehicles.length} vehiculo${vehicles.length == 1 ? '' : 's'} que puedes revisar.'
          '${preview.isEmpty ? '' : '\n\nAlgunos son: $preview'}'
          '\n\n${_visibilityHint()}';
    } catch (_) {
      return 'No pude consultar tus vehiculos ahora mismo. Puedes revisarlos desde el modulo Vehiculos.';
    }
  }

  Future<String> _answerPeopleCounts(String normalized) async {
    try {
      if (!await _isCompanyRole()) {
        return 'Por seguridad, esta vista solo muestra tu informacion y tus vehiculos asociados. Las listas generales de conductores, propietarios o usuarios se gestionan desde Empresa o Administrador.';
      }

      final conductores = await ApiService.getConductores();
      final propietarios = await ApiService.getPropietarios();
      final usuarios = await ApiService.getUsuarios();

      if (_containsAny(normalized, ['conductor', 'conductores'])) {
        return 'Hay ${conductores.length} conductor${conductores.length == 1 ? '' : 'es'} registrado${conductores.length == 1 ? '' : 's'} en la empresa.';
      }

      if (_containsAny(normalized, ['propietario', 'propietarios'])) {
        return 'Hay ${propietarios.length} propietario${propietarios.length == 1 ? '' : 's'} registrado${propietarios.length == 1 ? '' : 's'} en la empresa.';
      }

      return 'En la empresa hay ${usuarios.length} usuario${usuarios.length == 1 ? '' : 's'}, ${conductores.length} conductor${conductores.length == 1 ? '' : 'es'} y ${propietarios.length} propietario${propietarios.length == 1 ? '' : 's'} registrado${usuarios.length == 1 ? '' : 's'}.';
    } catch (_) {
      return 'No pude consultar ese conteo ahora mismo. Intenta de nuevo desde la vista de Empresa.';
    }
  }

  Future<String> _answerRequestTypes() async {
    try {
      final types = await ApiService.getTiposSolicitud();
      final preview = _previewItems(types, _genericName);

      if (types.isEmpty) {
        return 'No encontre tipos de solicitud disponibles ahora mismo. Puedes abrir Solicitudes para verificar las opciones activas.';
      }

      return 'Puedes trabajar con ${types.length} tipo${types.length == 1 ? '' : 's'} de solicitud.'
          '${preview.isEmpty ? '' : '\n\nOpciones visibles: $preview'}'
          '\n\nPara crear una, entra a Solicitudes y selecciona el tipo que necesites.';
    } catch (_) {
      return 'No pude consultar los tipos de solicitud ahora mismo. Puedes verlos desde el modulo Solicitudes.';
    }
  }

  Future<String> _answerMaintenanceTypes() async {
    try {
      final types = await ApiService.getTiposMantenimiento();
      final preview = _previewItems(types, _genericName);

      if (types.isEmpty) {
        return 'No encontre tipos de mantenimiento disponibles ahora mismo. Puedes abrir Mantenimientos para verificar las opciones activas.';
      }

      return 'Hay ${types.length} tipo${types.length == 1 ? '' : 's'} de mantenimiento disponible${types.length == 1 ? '' : 's'}.'
          '${preview.isEmpty ? '' : '\n\nOpciones: $preview'}'
          '\n\nSirven para clasificar mantenimientos preventivos, correctivos o sugeridos segun lo que tenga configurado la empresa.';
    } catch (_) {
      return 'No pude consultar los tipos de mantenimiento ahora mismo. Puedes revisarlos desde Mantenimientos.';
    }
  }

  Future<String> _answerProfile() async {
    try {
      final profile = await ApiService.getMiPerfil();
      final company = await ApiService.getMiEmpresa();

      if (profile == null && company == null) {
        return 'No pude encontrar tus datos de perfil en este momento. Puedes revisarlos desde Perfil.';
      }

      final name = _fullName(profile ?? const <String, dynamic>{});
      final email = _text(profile?['correo'] ?? profile?['email']);
      final phone = _text(profile?['telefono'] ?? profile?['phone']);
      final companyName = _text(
        company?['nombreEmpresa'] ??
            company?['nombre'] ??
            company?['razonSocial'],
      );

      return 'Estos son los datos principales que veo:'
          '${name.isEmpty ? '' : '\n\nNombre: $name'}'
          '${email.isEmpty ? '' : '\nCorreo: $email'}'
          '${phone.isEmpty ? '' : '\nTelefono: $phone'}'
          '${companyName.isEmpty ? '' : '\nEmpresa: $companyName'}'
          '\n\nSi algun dato esta mal, revisa Perfil o pide el ajuste a la empresa/administrador.';
    } catch (_) {
      return 'No pude consultar tu perfil ahora mismo. Puedes abrir Perfil para ver tus datos registrados.';
    }
  }

  String _maintenanceAnswer(String label, List<Map<String, dynamic>> items) {
    final preview = _previewItems(items, _maintenanceLabel);
    if (items.isEmpty) {
      return 'No encontre mantenimientos $label${label.endsWith('o') ? 's' : ''} en este momento.';
    }

    return 'Tienes ${items.length} mantenimiento${items.length == 1 ? '' : 's'} $label${items.length == 1 ? '' : 's'}.'
        '${preview.isEmpty ? '' : '\n\nAlgunos son: $preview'}'
        '\n\nPuedes revisar el detalle desde Mantenimientos.';
  }

  void _rememberResult(
    String topic,
    List<Map<String, dynamic>> items,
    List<_ChatAction> actions,
  ) {
    final normalizedTopic = topic == 'recordatorios' ? 'documentos' : topic;
    _memory[normalizedTopic] = _ChatMemory(items: items.take(12).toList());
    if (normalizedTopic == 'tramites') {
      _memory['solicitudes'] = _memory[normalizedTopic]!;
    }
    _lastTopic = normalizedTopic;
    _addActions(actions);
  }

  void _setActions(List<_ChatAction> actions) {
    _pendingBotActions = actions;
  }

  void _addActions(List<_ChatAction> actions) {
    if (actions.isEmpty) return;
    final merged = <String, _ChatAction>{
      for (final action in _pendingBotActions) action.target: action,
      for (final action in actions) action.target: action,
    };
    _pendingBotActions = merged.values.toList();
  }

  List<_ChatAction> _actionsForTopic(String? topic) {
    switch (topic) {
      case 'documentos':
      case 'recordatorios':
        return const [
          _ChatAction(label: 'Abrir Documentos', target: 'documentos'),
        ];
      case 'vehiculos':
        return const [
          _ChatAction(label: 'Abrir Vehiculos', target: 'vehiculos'),
        ];
      case 'mantenimientos':
        return const [
          _ChatAction(label: 'Abrir Mantenimientos', target: 'mantenimientos'),
        ];
      case 'tramites':
      case 'solicitudes':
        return const [
          _ChatAction(label: 'Abrir Solicitudes', target: 'solicitudes'),
        ];
      case 'notificaciones':
        return const [_ChatAction(label: 'Abrir Mensajes', target: 'mensajes')];
      default:
        return const [];
    }
  }

  String _smartRecommendation() {
    final docs = _memory['documentos']?.items ?? const <Map<String, dynamic>>[];
    final maintenances =
        _memory['mantenimientos']?.items ?? const <Map<String, dynamic>>[];
    final requests =
        _memory['solicitudes']?.items ??
        _memory['tramites']?.items ??
        const <Map<String, dynamic>>[];

    final expiredDocs = docs.where(_isDocumentExpired).length;
    final pendingMaintenances = maintenances
        .where(_isMaintenancePending)
        .length;
    final pendingRequests = requests.where(_isRequestPending).length;

    if (expiredDocs > 0) {
      return 'Recomendacion: lo mas urgente parece ser revisar los documentos vencidos antes que los proximos a vencer.';
    }
    if (pendingMaintenances > 0) {
      return 'Recomendacion: revisa los mantenimientos pendientes para evitar que se acumulen tareas del vehiculo.';
    }
    if (pendingRequests > 0) {
      return 'Recomendacion: dale una mirada a las solicitudes pendientes para no dejar tramites sin respuesta.';
    }

    return '';
  }

  Future<void> _saveUnknownQuestion(String question) async {
    final text = question.trim();
    if (text.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('faq_chatbot_unknown_questions');
    final items = <Map<String, dynamic>>[];

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          items.addAll(
            decoded.whereType<Map>().map((item) {
              return item.map((key, value) => MapEntry(key.toString(), value));
            }),
          );
        }
      } catch (_) {
        items.clear();
      }
    }

    items.add({
      'question': text,
      'role': widget.role,
      'userId': widget.userId,
      'createdAt': DateTime.now().toIso8601String(),
    });

    final recent = items.length > 80 ? items.sublist(items.length - 80) : items;
    await prefs.setString('faq_chatbot_unknown_questions', jsonEncode(recent));
  }

  String _followUpForTopic(String? topic) {
    switch (topic) {
      case 'tramites':
        return 'Tambien puedes preguntarme: "que documentos necesito", "como reviso el estado" o "como respondo una solicitud".';
      case 'recordatorios':
        return 'Tambien puedo orientarte sobre documentos vencidos, proximos vencimientos o mantenimientos programados.';
      case 'documentos':
        return 'Si luego preguntas "donde los encuentro", entendere que sigues hablando de documentos.';
      case 'vehiculos':
        return 'Tambien puedes preguntarme cuantos vehiculos ves, que placas tienes o donde revisar sus documentos.';
      case 'mantenimientos':
        return 'Puedes preguntarme como ver mantenimientos por placa o que significa mantenimiento sugerido.';
      case 'roles':
        return 'Ya estoy usando la vista con la que entraste, asi que las respuestas se ajustan automaticamente.';
      case 'acceso':
        return 'Tambien puedes preguntarme por registro de empresa, verificacion de correo o recuperacion de contrasena.';
      case 'notificaciones':
        return 'Puedes abrir Mensajes o la campana para ver el detalle y marcar notificaciones como leidas.';
      case 'perfil':
        return 'Tambien puedo orientarte sobre donde actualizar telefono, direccion o datos de la empresa.';
      case 'overview':
        return 'Puedes pedirme despues el detalle de documentos, solicitudes, mantenimientos, vehiculos o notificaciones.';
      default:
        return 'Puedes escribir la pregunta con tus palabras; intentare llevarte al modulo correcto.';
    }
  }

  String _topicLabel(String? topic) {
    switch (topic) {
      case 'tramites':
        return 'tramites';
      case 'recordatorios':
        return 'recordatorios';
      case 'documentos':
        return 'documentos';
      case 'vehiculos':
        return 'vehiculos';
      case 'mantenimientos':
        return 'mantenimientos';
      case 'roles':
        return 'roles de usuario';
      case 'acceso':
        return 'acceso a la plataforma';
      case 'notificaciones':
        return 'notificaciones';
      case 'perfil':
        return 'perfil';
      case 'overview':
        return 'resumen general';
      case 'soporte':
        return 'soporte';
      default:
        return 'ese tema';
    }
  }

  String? _detectTopic(String normalized) {
    if (_containsAny(normalized, [
      'resumen',
      'estado general',
      'que tengo pendiente',
      'que pendientes tengo',
      'que debo revisar',
    ])) {
      return 'overview';
    }
    if (_containsAny(normalized, [
      'tramite',
      'solicitud',
      'certificado',
      'constancia',
    ])) {
      return 'tramites';
    }
    if (_containsAny(normalized, [
      'recordatorio',
      'vencimiento',
      'vencido',
      'vence',
      'expira',
    ])) {
      return 'recordatorios';
    }
    if (_containsAny(normalized, [
      'documento',
      'pdf',
      'soat',
      'licencia',
      'tecnomecanica',
      'poliza',
    ])) {
      return 'documentos';
    }
    if (_containsAny(normalized, [
      'vehiculo',
      'vehiculos',
      'placa',
      'placas',
      'carro',
      'carros',
      'flota',
    ])) {
      return 'vehiculos';
    }
    if (_containsAny(normalized, [
      'mantenimiento',
      'taller',
      'revision',
      'aceite',
    ])) {
      return 'mantenimientos';
    }
    if (_containsAny(normalized, [
      'login',
      'iniciar sesion',
      'entrar',
      'registro',
      'registrarme',
      'contrasena',
      'password',
      'rut',
    ])) {
      return 'acceso';
    }
    if (_containsAny(normalized, [
      'empresa',
      'propietario',
      'conductor',
      'rol',
      'roles',
    ])) {
      return 'roles';
    }
    if (_containsAny(normalized, [
      'notificacion',
      'notificaciones',
      'mensaje',
      'mensajes',
      'alerta',
      'alertas',
      'campana',
    ])) {
      return 'notificaciones';
    }
    if (_containsAny(normalized, [
      'perfil',
      'mis datos',
      'mi informacion',
      'telefono',
      'direccion',
      'correo',
      'quien soy',
    ])) {
      return 'perfil';
    }
    if (_containsAny(normalized, [
      'error',
      'problema',
      'soporte',
      'no funciona',
    ])) {
      return 'soporte';
    }
    return null;
  }

  String _findAnswer(String question) {
    final normalized = _normalize(question);

    final intentAnswer = _answerByIntent(normalized);
    if (intentAnswer != null) return intentAnswer;

    final exactMatch = _answers.where((answer) {
      return _normalize(answer.question) == normalized;
    }).toList();
    if (exactMatch.isNotEmpty) return exactMatch.first.answer;

    final scored =
        _answers
            .map(
              (answer) => _ScoredAnswer(
                faq: answer,
                score: _scoreAnswer(answer, normalized),
              ),
            )
            .where((item) => item.score > 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    if (scored.isNotEmpty && scored.first.score >= 2) {
      return scored.first.faq.answer;
    }

    final section = _sectionByTitle(_selectedSectionTitle);
    if (section != null) {
      final options = section.questions
          .take(3)
          .map((answer) => answer.question)
          .join(', ');
      return 'No encontre una respuesta exacta. En ${section.title} puedo ayudarte con: $options.';
    }

    return 'No encontre una respuesta exacta. Prueba con documentos, vehiculos, solicitudes, mantenimientos, perfil o notificaciones.';
  }

  String? _answerByIntent(String normalized) {
    if (_containsAny(normalized, [
      'que es trackfile',
      'para que sirve',
      'objetivo',
      'proposito',
      'funcion principal',
    ])) {
      return 'TrackFile es una aplicacion para gestionar documentos, vehiculos, mantenimientos, solicitudes y alertas. Su objetivo es centralizar la informacion operativa y ayudar al usuario con asistencia inmediata, orientacion sobre tramites y recordatorios de vencimientos.';
    }

    if (_containsAny(normalized, [
      'iniciar sesion',
      'login',
      'entrar',
      'contrasena',
      'password',
      'olvide',
      'correo',
      'registro',
      'registrarme',
      'unirme',
      'rut',
    ])) {
      return _answerForAccess(normalized);
    }

    if (_containsAny(normalized, [
      'rol',
      'roles',
      'empresa',
      'propietario',
      'conductor',
      'administrador',
      'secretaria',
    ])) {
      return _answerForRoles(normalized);
    }

    if (_containsAny(normalized, [
      'hola',
      'buenos dias',
      'buenas tardes',
      'buenas noches',
      'ayudame',
      'necesito ayuda',
    ])) {
      return 'Claro. Puedo ayudarte con tres cosas principales: orientarte en tramites, explicarte donde realizar acciones dentro de TrackFile y recordarte donde revisar vencimientos o mantenimientos. Escribe, por ejemplo: "como hago una solicitud", "que documentos estan por vencer" o "donde veo mantenimientos".';
    }

    if (_containsAny(normalized, [
      'tramite',
      'tramites',
      'proceso',
      'procedimiento',
      'certificado',
      'certificacion',
      'constancia',
      'solicitar',
      'pedir',
    ])) {
      return _answerForProcedure(normalized);
    }

    if (_containsAny(normalized, [
      'recordatorio',
      'recordatorios',
      'recordar',
      'vencer',
      'vence',
      'vencimiento',
      'vencido',
      'caduca',
      'expira',
      'proximo',
    ])) {
      return _answerForReminders(normalized);
    }

    if (_containsAny(normalized, [
      'estado',
      'seguimiento',
      'pendiente',
      'aprobado',
      'rechazado',
      'radicado',
    ])) {
      return 'Para hacer seguimiento entra a Solicitudes. Alli puedes revisar el estado del tramite, fecha de envio, historial y respuesta de la empresa. Si eres empresa, tambien puedes gestionar solicitudes pendientes y responderlas desde ese modulo.';
    }

    if (_containsAny(normalized, [
      'subir',
      'cargar',
      'adjuntar',
      'archivo',
      'pdf',
      'documento requerido',
      'documentos requeridos',
    ])) {
      return 'Para cargar documentos ve a Documentos. Selecciona la persona o vehiculo correspondiente, el tipo de documento, fecha de vencimiento si aplica y adjunta el PDF. Revisa que quede asociado al usuario o vehiculo correcto para que los recordatorios funcionen bien.';
    }

    if (_containsAny(normalized, [
      'mantenimiento',
      'mantenimientos',
      'taller',
      'aceite',
      'preventivo',
      'correctivo',
      'programado',
    ])) {
      return 'En Mantenimientos puedes revisar actividades sugeridas, programadas y realizadas. Si vienes desde Vehiculos, puedes filtrar por placa. Usa esa seccion para anticiparte a revisiones y dejar trazabilidad del estado del vehiculo.';
    }

    if (_containsAny(normalized, [
      'vehiculo',
      'vehiculos',
      'placa',
      'flota',
      'carro',
      'auto',
      'bus',
    ])) {
      return 'Para consultar vehiculos entra a Vehiculos. Puedes buscar por placa y revisar datos del vehiculo, propietario, conductor, documentos y mantenimientos asociados. Si eres empresa, tambien puedes navegar desde Conductores o Propietarios hacia los vehiculos relacionados.';
    }

    if (_containsAny(normalized, [
      'buscar',
      'busqueda',
      'filtrar',
      'encontrar',
      'donde esta',
    ])) {
      return 'Usa el buscador superior del panel para encontrar secciones o informacion como documentos, vehiculos, placa, solicitudes o mantenimientos. Si estas en una tabla, tambien puedes usar el buscador interno de esa vista para filtrar resultados.';
    }

    if (_containsAny(normalized, [
      'soat',
      'tecnomecanica',
      'licencia',
      'tarjeta de propiedad',
      'poliza',
      'seguro',
    ])) {
      return 'Ese tipo de documento se gestiona desde Documentos. Busca el vehiculo o persona correspondiente, revisa la fecha de vencimiento y verifica que el PDF este cargado. Si esta vencido o proximo a vencer, aparecera como alerta en Inicio o Mensajes.';
    }

    if (_containsAny(normalized, [
      'notificacion',
      'notificaciones',
      'mensaje',
      'mensajes',
      'alerta',
      'campana',
    ])) {
      return 'Las notificaciones se revisan desde Mensajes o desde la campana del panel superior. Alli encontraras avisos sobre documentos por vencer, solicitudes y mantenimientos. Tambien puedes revisar tus preferencias desde Perfil.';
    }

    if (_containsAny(normalized, [
      'no funciona',
      'error',
      'problema',
      'soporte',
      'contacto',
      'ayuda tecnica',
    ])) {
      return 'Si algo no funciona, primero verifica tu conexion y vuelve a iniciar sesion. Si el problema continua, toma nota de la seccion, accion y mensaje de error. Puedes contactar soporte en trackfile.noreply@gmail.com o escribir por Mensajes a tu empresa.';
    }

    return null;
  }

  String _answerForAccess(String normalized) {
    if (_containsAny(normalized, [
      'registro',
      'registrarme',
      'unirme',
      'rut',
    ])) {
      return 'Para registrarte como empresa usa la opcion Unete, completa los datos solicitados y adjunta el RUT en PDF. Despues revisa tu correo para confirmar la verificacion. La validacion de la empresa puede tardar segun el proceso definido.';
    }

    if (_containsAny(normalized, ['contrasena', 'password', 'olvide'])) {
      return 'Si olvidaste tu contrasena, usa la opcion de recuperacion si esta disponible en Login. Si aun no aparece habilitada, contacta a la empresa o al soporte de TrackFile para restablecer el acceso.';
    }

    return 'Para entrar a TrackFile ve a Inicia sesion, escribe tu correo y contrasena. Si tu correo aun no esta verificado o la empresa no ha sido validada, revisa el correo de confirmacion o comunicate con soporte.';
  }

  String _answerForRoles(String normalized) {
    if (_containsAny(normalized, ['empresa'])) {
      return 'El rol Empresa puede gestionar conductores, propietarios, vehiculos, documentos, solicitudes y mantenimientos. Es el rol con mayor control operativo dentro de la compania.';
    }

    if (_containsAny(normalized, ['propietario'])) {
      return 'El rol Propietario puede consultar sus vehiculos asociados, documentos, mantenimientos, solicitudes, perfil y notificaciones relacionadas.';
    }

    if (_containsAny(normalized, ['conductor'])) {
      return 'El rol Conductor puede revisar su vehiculo asignado, documentos, mantenimientos, solicitudes, perfil y notificaciones.';
    }

    return 'TrackFile maneja roles como Empresa, Propietario, Conductor, Secretaria y Administrador. Cada rol ve opciones distintas segun sus responsabilidades dentro del sistema.';
  }

  String _answerForProcedure(String normalized) {
    if (_containsAny(normalized, [
      'certificado',
      'certificacion',
      'constancia',
    ])) {
      return 'Para solicitar un certificado o constancia entra a Solicitudes, elige el tipo de solicitud disponible, completa la descripcion y envia el tramite. Luego revisa el estado en la misma seccion hasta que la empresa responda.';
    }

    if (_containsAny(normalized, ['documento', 'pdf', 'archivo'])) {
      return 'Si el tramite requiere soporte documental, ve a Documentos y verifica que el archivo este cargado y vigente. Si falta un PDF, cargalo con el tipo de documento correcto antes de crear o continuar la solicitud.';
    }

    return 'Para realizar un tramite dentro de TrackFile, entra a Solicitudes, selecciona el tipo de solicitud, agrega la informacion requerida y enviala. Despues puedes hacer seguimiento desde el historial de la solicitud.';
  }

  String _answerForReminders(String normalized) {
    if (_containsAny(normalized, [
      'documento',
      'soat',
      'tecnomecanica',
      'licencia',
      'poliza',
    ])) {
      return 'Para recordatorios de documentos, revisa Inicio y Documentos. Alli aparecen documentos vencidos o proximos a vencer. Mantener la fecha de vencimiento actualizada permite que TrackFile genere alertas utiles para el usuario.';
    }

    if (_containsAny(normalized, [
      'mantenimiento',
      'revision',
      'taller',
      'aceite',
    ])) {
      return 'Para recordatorios de mantenimiento, entra a Mantenimientos. Puedes revisar actividades programadas o sugeridas y, si aplica, filtrarlas por vehiculo para anticiparte a revisiones importantes.';
    }

    return 'Los recordatorios se consultan principalmente en Inicio, Mensajes y Notificaciones. TrackFile te orienta sobre documentos proximos a vencer, solicitudes pendientes y mantenimientos programados.';
  }

  bool _containsAny(String value, List<String> terms) {
    final normalizedValue = _normalize(value);
    final tokens = normalizedValue
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .toList();

    for (final term in terms) {
      final normalizedTerm = _normalize(term);
      if (normalizedTerm.isEmpty) continue;
      if (normalizedValue.contains(normalizedTerm)) return true;

      final termTokens = normalizedTerm.split(' ');
      if (termTokens.length > 1) {
        final matched = termTokens.every((termToken) {
          return tokens.any((token) => _isFuzzyMatch(token, termToken));
        });
        if (matched) return true;
        continue;
      }

      if (tokens.any((token) => _isFuzzyMatch(token, normalizedTerm))) {
        return true;
      }
    }

    return false;
  }

  bool _isFuzzyMatch(String token, String term) {
    if (token == term) return true;
    if (token.length >= 4 && term.startsWith(token)) return true;
    if (term.length >= 4 && token.startsWith(term)) return true;

    final minLength = math.min(token.length, term.length);
    if (minLength < 5) return false;

    final distance = _levenshteinDistance(token, term);
    final allowed = minLength <= 6 ? 1 : 2;
    return distance <= allowed;
  }

  int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (index) => index);
    for (var i = 0; i < a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final insertCost = current[j] + 1;
        final deleteCost = previous[j + 1] + 1;
        final replaceCost = previous[j] + (a[i] == b[j] ? 0 : 1);
        current[j + 1] = math.min(
          math.min(insertCost, deleteCost),
          replaceCost,
        );
      }
      previous = current;
    }

    return previous[b.length];
  }

  Future<String> _currentRole() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('role') ?? widget.role).toLowerCase().trim();
  }

  Future<String?> _currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('user_id') ?? widget.userId;
    return id?.trim().isEmpty == true ? null : id;
  }

  Future<bool> _isCompanyRole() async {
    return _isCompanyRoleName(await _currentRole());
  }

  bool _isCompanyRoleName(String role) {
    return role.contains('empresa') ||
        role.contains('admin') ||
        role.contains('secretaria');
  }

  String _visibilityHint() {
    final role = widget.role.toLowerCase();
    if (_isCompanyRoleName(role)) {
      return 'Estos datos pueden abarcar la informacion general de la empresa.';
    }

    return 'Solo consulto informacion asociada a tu usuario o a tus vehiculos.';
  }

  Future<List<Map<String, dynamic>>> _loadDocumentsForCurrentRole() async {
    final role = await _currentRole();

    if (_isCompanyRoleName(role)) {
      return ApiService.getDocumentosEmpresa();
    }

    return ApiService.getMisDocumentos();
  }

  Future<List<Map<String, dynamic>>> _loadVehiclesForCurrentRole() async {
    final role = await _currentRole();
    final userId = await _currentUserId();
    return ApiService.getVehiculosPorRol(role: role, userId: userId);
  }

  Future<List<Map<String, dynamic>>> _loadMantenimientosForCurrentRole() async {
    final role = await _currentRole();
    final userId = await _currentUserId();
    final mantenimientos = await ApiService.getMantenimientos(
      role: role,
      userId: userId,
    );

    if (_isCompanyRoleName(role)) {
      return mantenimientos;
    }

    final vehicles = await _loadVehiclesForCurrentRole();
    if (vehicles.isEmpty) return <Map<String, dynamic>>[];

    final vehicleIds = vehicles
        .map(_vehicleId)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet();
    final plates = vehicles
        .map(_vehiclePlate)
        .where((plate) => plate.isNotEmpty)
        .map(_normalize)
        .toSet();

    return mantenimientos.where((item) {
      final itemVehicleId = _maintenanceVehicleId(item);
      final itemPlate = _normalize(_maintenancePlate(item));

      return (itemVehicleId.isNotEmpty && vehicleIds.contains(itemVehicleId)) ||
          (itemPlate.isNotEmpty && plates.contains(itemPlate));
    }).toList();
  }

  List<Map<String, dynamic>> _documentsExpiringSoon(
    List<Map<String, dynamic>> docs,
  ) {
    return docs.where((doc) {
      if (!_isDocumentActive(doc)) return false;
      final date = _documentExpirationDate(doc);
      if (date == null) return false;
      final today = _dateOnly(DateTime.now());
      final docDate = _dateOnly(date);
      final days = docDate.difference(today).inDays;
      return days >= 0 && days <= 30;
    }).toList()..sort((a, b) {
      final ad = _documentExpirationDate(a);
      final bd = _documentExpirationDate(b);
      if (ad == null || bd == null) return 0;
      return ad.compareTo(bd);
    });
  }

  bool _isDocumentExpired(Map<String, dynamic> doc) {
    if (!_isDocumentActive(doc)) return false;

    final status = _normalize(
      _text(
        doc['estado'] ??
            doc['estadoDocumentoTexto'] ??
            doc['estado_documento_texto'] ??
            doc['estadoVencimiento'] ??
            doc['status'],
      ),
    );

    if (status.contains('vencido') || status.contains('expirado')) {
      return true;
    }

    final date = _documentExpirationDate(doc);
    if (date == null) return false;
    return _dateOnly(date).isBefore(_dateOnly(DateTime.now()));
  }

  bool _isDocumentActive(Map<String, dynamic> doc) {
    final rawActive =
        doc['activo'] ??
        doc['isActive'] ??
        doc['active'] ??
        doc['estadoDocumento'] ??
        doc['estado_documento'] ??
        doc['estadoActivo'] ??
        doc['estado_activo'] ??
        doc['habilitado'];

    if (rawActive is bool) return rawActive;
    if (rawActive is num) return rawActive != 0;

    final activeText = _normalize(_text(rawActive));
    if (activeText.isNotEmpty) {
      if (_containsAny(activeText, [
        'false',
        'no',
        '0',
        'inactivo',
        'inactiva',
        'desactivado',
        'desactivada',
        'eliminado',
        'eliminada',
        'archivado',
        'archivada',
      ])) {
        return false;
      }

      if (_containsAny(activeText, [
        'true',
        'si',
        '1',
        'activo',
        'activa',
        'habilitado',
        'habilitada',
      ])) {
        return true;
      }
    }

    final status = _normalize(
      _text(
        doc['estadoRegistro'] ??
            doc['estado_registro'] ??
            doc['estadoDocumento'] ??
            doc['estado_documento'] ??
            doc['estadoGeneral'] ??
            doc['estado_general'] ??
            doc['estado'] ??
            doc['status'],
      ),
    );

    if (status.isEmpty) return true;
    return !_containsAny(status, [
      'inactivo',
      'inactiva',
      'desactivado',
      'desactivada',
      'eliminado',
      'eliminada',
      'archivado',
      'archivada',
    ]);
  }

  DateTime? _documentExpirationDate(Map<String, dynamic> doc) {
    final raw =
        doc['fechaVencimiento'] ??
        doc['fecha_vencimiento'] ??
        doc['vencimiento'] ??
        doc['expiryDate'] ??
        doc['fechaExpiracion'] ??
        doc['fecha_expiracion'];

    return _parseDate(raw);
  }

  bool _isRequestPending(Map<String, dynamic> request) {
    final status = _normalize(
      _text(
        request['estado'] ??
            request['estadoSolicitud'] ??
            request['estado_solicitud'] ??
            request['status'],
      ),
    );

    if (status.isEmpty) return true;
    return status.contains('pendiente') ||
        status.contains('revision') ||
        status.contains('proceso') ||
        status.contains('creada') ||
        status.contains('enviada') ||
        status.contains('radicada') ||
        status.contains('abierta');
  }

  bool _isMaintenanceScheduled(Map<String, dynamic> item) {
    final status = _maintenanceStatus(item);
    return status.contains('programado') || status.contains('agendado');
  }

  bool _isMaintenanceSuggested(Map<String, dynamic> item) {
    final status = _maintenanceStatus(item);
    return status.contains('sugerido') || status.contains('recomendado');
  }

  bool _isMaintenancePending(Map<String, dynamic> item) {
    final status = _maintenanceStatus(item);
    if (status.contains('realizado') ||
        status.contains('completado') ||
        status.contains('finalizado') ||
        status.contains('cancelado')) {
      return false;
    }

    return status.contains('pendiente') ||
        status.contains('programado') ||
        status.contains('sugerido') ||
        status.contains('agendado') ||
        status.isEmpty;
  }

  String _maintenanceStatus(Map<String, dynamic> item) {
    return _normalize(
      _text(
        item['estado'] ??
            item['estadoMantenimiento'] ??
            item['estado_mantenimiento'] ??
            item['status'],
      ),
    );
  }

  String _documentLabel(Map<String, dynamic> doc) {
    return _text(
      doc['nombreTipoDocumento'] ??
          doc['tipoDocumento'] ??
          doc['tipo_documento'] ??
          doc['nombre'] ??
          doc['descripcion'] ??
          'Documento',
    );
  }

  String _documentLabelWithDate(Map<String, dynamic> doc) {
    final date = _documentExpirationDate(doc);
    final suffix = date == null ? '' : ' (${_formatDate(date)})';
    return '${_documentLabel(doc)}$suffix';
  }

  String _requestLabel(Map<String, dynamic> request) {
    final type = _text(
      request['tipoSolicitud'] ??
          request['nombreTipoSolicitud'] ??
          request['tipo_solicitud'] ??
          request['tipo'] ??
          'Solicitud',
    );
    final status = _text(
      request['estado'] ??
          request['estadoSolicitud'] ??
          request['estado_solicitud'] ??
          request['status'],
    );

    return status.isEmpty ? type : '$type ($status)';
  }

  String _maintenanceLabel(Map<String, dynamic> item) {
    final type = _text(
      item['tipoMantenimiento'] ??
          item['nombreTipoMantenimiento'] ??
          item['tipo_mantenimiento'] ??
          item['tipo'] ??
          'Mantenimiento',
    );
    final plate = _text(
      item['placa'] ??
          item['vehiculoPlaca'] ??
          item['vehiculo_placa'] ??
          (item['vehiculo'] is Map ? item['vehiculo']['placa'] : null),
    );

    return plate.isEmpty ? type : '$type - $plate';
  }

  String _vehicleLabel(Map<String, dynamic> vehicle) {
    final plate = _vehiclePlate(vehicle);
    final brand = _text(vehicle['marca'] ?? vehicle['brand']);
    final model = _text(vehicle['modelo'] ?? vehicle['model']);
    final detail = [brand, model].where((part) => part.isNotEmpty).join(' ');

    if (plate.isEmpty) {
      return detail.isEmpty ? 'Vehiculo' : detail;
    }

    return detail.isEmpty ? plate : '$plate - $detail';
  }

  String _vehiclePlate(Map<String, dynamic> vehicle) {
    return _text(
      vehicle['placa'] ??
          vehicle['plate'] ??
          vehicle['numeroPlaca'] ??
          vehicle['numero_placa'],
    );
  }

  String? _vehicleId(Map<String, dynamic> vehicle) {
    final id = vehicle['idVehiculo'] ?? vehicle['id_vehiculo'] ?? vehicle['id'];
    final text = _text(id).trim();
    return text.isEmpty ? null : text;
  }

  String _maintenanceVehicleId(Map<String, dynamic> item) {
    final vehicle = item['vehiculo'];
    return _text(
      item['idVehiculo'] ??
          item['id_vehiculo'] ??
          item['vehiculoId'] ??
          (vehicle is Map
              ? vehicle['idVehiculo'] ?? vehicle['id_vehiculo'] ?? vehicle['id']
              : null),
    );
  }

  String _maintenancePlate(Map<String, dynamic> item) {
    final vehicle = item['vehiculo'];
    return _text(
      item['placa'] ??
          item['vehiculoPlaca'] ??
          item['vehiculo_placa'] ??
          (vehicle is Map ? vehicle['placa'] : null),
    );
  }

  String _genericName(Map<String, dynamic> item) {
    return _text(
      item['nombre'] ??
          item['name'] ??
          item['descripcion'] ??
          item['tipo'] ??
          item['label'] ??
          item['titulo'],
    );
  }

  String _fullName(Map<String, dynamic> item) {
    final first = _text(item['nombre'] ?? item['name'] ?? item['nombres']);
    final last = _text(
      item['apellido'] ?? item['lastName'] ?? item['apellidos'],
    );
    return [first, last].where((part) => part.isNotEmpty).join(' ');
  }

  String _previewItems(
    List<Map<String, dynamic>> items,
    String Function(Map<String, dynamic>) labelBuilder,
  ) {
    final labels = items
        .take(3)
        .map(labelBuilder)
        .where((label) => label.trim().isNotEmpty)
        .toList();

    return labels.join(', ');
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    final parts = text.split(RegExp(r'[/\-]'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _text(dynamic value) {
    if (value == null) return '';
    if (value is Map) {
      return _text(
        value['nombre'] ??
            value['name'] ??
            value['descripcion'] ??
            value['tipo'] ??
            value['label'],
      );
    }
    return value.toString();
  }

  int _scoreAnswer(_FaqAnswer answer, String normalizedQuestion) {
    var score = 0;

    for (final keyword in answer.keywords) {
      final normalizedKeyword = _normalize(keyword);
      if (normalizedQuestion.contains(normalizedKeyword)) {
        score += normalizedKeyword.length > 8 ? 3 : 2;
      }
    }

    for (final word in _normalize(answer.question).split(' ')) {
      if (word.length > 3 && normalizedQuestion.contains(word)) {
        score++;
      }
    }

    return score;
  }

  _FaqSection? _sectionByTitle(String title) {
    for (final section in _sections) {
      if (section.title == title) return section;
    }
    return null;
  }

  void _selectSection(String title) {
    setState(() {
      _selectedSectionTitle = title;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('Ã¡', 'a')
        .replaceAll('Ã©', 'e')
        .replaceAll('Ã­', 'i')
        .replaceAll('Ã³', 'o')
        .replaceAll('Ãº', 'u')
        .replaceAll('Ã±', 'n')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  void _moveLauncher(DragUpdateDetails details) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 900;
    final launcherWidth = compact ? 56.0 : 154.0;
    const launcherHeight = 56.0;

    setState(() {
      if (compact) {
        _mobileLauncherLeft = (_mobileLauncherLeft + details.delta.dx).clamp(
          8.0,
          math.max(8.0, size.width - launcherWidth - 8),
        );
        _mobileLauncherBottom = (_mobileLauncherBottom - details.delta.dy)
            .clamp(24.0, math.max(24.0, size.height - launcherHeight - 24));
      } else {
        _desktopLauncherLeft = (_desktopLauncherLeft + details.delta.dx).clamp(
          12.0,
          math.max(12.0, size.width - launcherWidth - 12),
        );
        _desktopLauncherBottom = (_desktopLauncherBottom - details.delta.dy)
            .clamp(12.0, math.max(12.0, size.height - launcherHeight - 12));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 900;
    final draggableLauncher = !_isOpen;

    return Positioned(
      left: compact
          ? (draggableLauncher ? _mobileLauncherLeft : 12)
          : (draggableLauncher ? _desktopLauncherLeft : 22),
      right: compact && _isOpen ? 12 : null,
      bottom: compact
          ? (draggableLauncher ? _mobileLauncherBottom : 12)
          : (draggableLauncher ? _desktopLauncherBottom : 22),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _isOpen
                  ? _buildChatWindow(context, compact: compact)
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
            _buildLauncher(compact: compact, draggable: draggableLauncher),
          ],
        ),
      ),
    );
  }

  Widget _buildLauncher({required bool compact, bool draggable = false}) {
    if (compact) {
      final button = FloatingActionButton(
        heroTag: 'faq_chatbot_${widget.role}_${widget.userId ?? 'guest'}',
        backgroundColor: _chatPrimary,
        foregroundColor: Colors.white,
        elevation: 8,
        tooltip: _isOpen ? context.t('chat.close') : context.t('chat.open'),
        onPressed: () {
          setState(() {
            _isOpen = !_isOpen;
          });

          if (_isOpen) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _scrollToBottom();
              _composerFocus.requestFocus();
            });
          }
        },
        child: Icon(
          _isOpen ? Icons.close_rounded : Icons.support_agent_rounded,
        ),
      );

      if (!draggable) return button;

      return GestureDetector(onPanUpdate: _moveLauncher, child: button);
    }

    final button = FloatingActionButton.extended(
      heroTag: 'faq_chatbot_${widget.role}_${widget.userId ?? 'guest'}',
      backgroundColor: _chatPrimary,
      foregroundColor: Colors.white,
      elevation: 8,
      icon: Icon(_isOpen ? Icons.close_rounded : Icons.support_agent_rounded),
      label: Text(
        _isOpen
            ? context.t('chat.close')
            : (compact ? context.t('chat.help') : context.t('chat.open')),
      ),
      onPressed: () {
        setState(() {
          _isOpen = !_isOpen;
        });

        if (_isOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _scrollToBottom();
            _composerFocus.requestFocus();
          });
        }
      },
    );

    if (!draggable) return button;

    return GestureDetector(onPanUpdate: _moveLauncher, child: button);
  }

  Widget _buildChatWindow(BuildContext context, {required bool compact}) {
    final size = MediaQuery.sizeOf(context);
    final width = compact
        ? size.width - 24
        : math.min(math.max(size.width * 0.34, 380.0), 440.0);
    final availableHeight = math.max(size.height - 110, 360.0);
    final height = compact
        ? math.min(size.height - 92, 620.0)
        : math.min(availableHeight, 650.0);

    return Material(
      elevation: 18,
      shadowColor: _tone(Colors.black, 0.26),
      borderRadius: BorderRadius.circular(compact ? 18 : 20),
      color: Colors.transparent,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 18 : 20),
          border: Border.all(color: _tone(Colors.white, 0.7)),
        ),
        child: Column(
          children: [
            _buildHeader(compact: compact),
            _buildTopicPanel(compact: compact),
            Expanded(child: _buildMessages()),
            if (_isTyping) _buildTypingIndicator(),
            _buildComposer(compact: compact),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required bool compact}) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, compact ? 12 : 14, 8, compact ? 12 : 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF20209A), Color(0xFF3330BE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _tone(Colors.white, 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.support_agent_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('chat.title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: _chatAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ayuda inmediata para ${widget.role}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.t('chat.clearHistory'),
            color: Colors.white,
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: _clearHistory,
          ),
          IconButton(
            tooltip: 'Cerrar',
            color: Colors.white,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: () => setState(() => _isOpen = false),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicPanel({required bool compact}) {
    final selectedSection = _sectionByTitle(_selectedSectionTitle);
    if (selectedSection == null) return const SizedBox.shrink();
    final showFullPanel = _showShortcuts;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        12,
        compact ? 8 : 10,
        12,
        showFullPanel ? 10 : 8,
      ),
      decoration: const BoxDecoration(
        color: _chatSurface,
        border: Border(bottom: BorderSide(color: _chatLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                showFullPanel
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.tips_and_updates_rounded,
                size: 18,
                color: _chatPrimary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  showFullPanel
                      ? context.t('chat.shortcutsOpen')
                      : context.t('chat.shortcutsClosed'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _chatInk,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _showShortcuts = !_showShortcuts),
                icon: Icon(
                  showFullPanel
                      ? Icons.visibility_off_rounded
                      : Icons.auto_awesome_rounded,
                  size: 16,
                ),
                label: Text(showFullPanel ? 'Ocultar' : 'Mostrar'),
                style: TextButton.styleFrom(
                  foregroundColor: _chatPrimary,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (!showFullPanel)
            const SizedBox.shrink()
          else ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _sections.map((section) {
                  final selected = section.title == selectedSection.title;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: selected,
                      avatar: Icon(
                        section.icon,
                        size: 16,
                        color: selected ? Colors.white : _chatPrimary,
                      ),
                      label: Text(section.title),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : _chatInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      selectedColor: _chatPrimary,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected ? _chatPrimary : _chatLine,
                      ),
                      onSelected: (_) => _selectSection(section.title),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              selectedSection.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _chatMuted,
                fontSize: 11.5,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedSection.questions.take(compact ? 4 : 5).map((
                answer,
              ) {
                return ActionChip(
                  avatar: const Icon(
                    Icons.bolt_rounded,
                    size: 15,
                    color: _chatAccent,
                  ),
                  label: Text(answer.question),
                  labelStyle: const TextStyle(
                    color: _chatInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: _chatLine),
                  onPressed: () => _sendMessage(answer.question),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return Container(
      color: const Color(0xFFFAFBFE),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          return _MessageBubble(
            message: _messages[index],
            onActionSelected: _handleChatAction,
          );
        },
      ),
    );
  }

  void _handleChatAction(_ChatAction action) {
    final section = _sectionForAction(action.target);
    if (section == null) return;

    final role = widget.role.trim().isEmpty
        ? 'empresa'
        : widget.role.toLowerCase().trim();

    context.goNamed(
      'dashboard_section',
      pathParameters: {'role': role, 'section': section},
    );
  }

  String? _sectionForAction(String target) {
    switch (target) {
      case 'documentos':
      case 'mantenimientos':
      case 'solicitudes':
      case 'vehiculos':
      case 'mensajes':
      case 'conductores':
      case 'propietarios':
      case 'perfil':
        return target;
      default:
        return null;
    }
  }

  Widget _buildTypingIndicator() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFAFBFE),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _chatLine),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text(
                'Escribiendo',
                style: TextStyle(
                  color: _chatMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer({required bool compact}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _composerFocus.requestFocus(),
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 10, 12, compact ? 10 : 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _chatLine)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _composerFocus,
                autofocus: false,
                showCursor: true,
                minLines: 1,
                maxLines: compact ? 3 : 4,
                textInputAction: TextInputAction.send,
                keyboardType: TextInputType.multiline,
                onTap: () => _composerFocus.requestFocus(),
                onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText: context.t('chat.placeholder'),
                  hintStyle: const TextStyle(color: _chatMuted, fontSize: 13),
                  isDense: true,
                  filled: true,
                  fillColor: _chatSurface,
                  prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                  prefixIconColor: _chatMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: _chatPrimary,
                      width: 1.4,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 46,
              height: 46,
              child: IconButton.filled(
                tooltip: context.t('chat.send'),
                style: IconButton.styleFrom(
                  backgroundColor: _chatPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _chatLine,
                ),
                onPressed: _isTyping ? null : () => _sendMessage(),
                icon: const Icon(Icons.send_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final ValueChanged<_ChatAction> onActionSelected;

  const _MessageBubble({required this.message, required this.onActionSelected});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final maxWidth = math.min(MediaQuery.sizeOf(context).width * 0.72, 320.0);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isUser ? 16 : 5),
      bottomRight: Radius.circular(isUser ? 5 : 16),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const _BubbleAvatar(isUser: false),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isUser ? const Color(0xFF3330BE) : Colors.white,
                  borderRadius: radius,
                  border: Border.all(
                    color: isUser ? const Color(0xFF3330BE) : _chatLine,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _tone(Colors.black, 0.04),
                      offset: const Offset(0, 3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: TextStyle(
                          color: isUser ? Colors.white : _chatInk,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!isUser && message.actions.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: message.actions.map((action) {
                            return ActionChip(
                              avatar: const Icon(
                                Icons.open_in_new_rounded,
                                size: 15,
                                color: _chatPrimary,
                              ),
                              label: Text(action.label),
                              labelStyle: const TextStyle(
                                color: _chatPrimary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                              backgroundColor: _tone(_chatPrimary, 0.08),
                              side: BorderSide(
                                color: _tone(_chatPrimary, 0.22),
                              ),
                              onPressed: () => onActionSelected(action),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Text(
                        message.timeLabel,
                        style: TextStyle(
                          color: isUser
                              ? _tone(Colors.white, 0.72)
                              : _chatMuted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 7),
            const _BubbleAvatar(isUser: true),
          ],
        ],
      ),
    );
  }
}

class _BubbleAvatar extends StatelessWidget {
  final bool isUser;

  const _BubbleAvatar({required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFFE9ECF8) : const Color(0xFFE6F7F5),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        isUser ? Icons.person_rounded : Icons.support_agent_rounded,
        size: 17,
        color: isUser ? const Color(0xFF3330BE) : const Color(0xFF148F82),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime createdAt;
  final List<_ChatAction> actions;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.createdAt,
    this.actions = const [],
  });

  factory _ChatMessage.user(String text, {DateTime? createdAt}) {
    return _ChatMessage(
      text: text,
      isUser: true,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  factory _ChatMessage.bot(
    String text, {
    DateTime? createdAt,
    List<_ChatAction> actions = const [],
  }) {
    return _ChatMessage(
      text: text,
      isUser: false,
      createdAt: createdAt ?? DateTime.now(),
      actions: actions,
    );
  }

  static _ChatMessage? fromJson(Map<dynamic, dynamic> json) {
    final text = json['text']?.toString() ?? '';
    if (text.trim().isEmpty) return null;

    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();

    final actions = <_ChatAction>[];
    final rawActions = json['actions'];
    if (rawActions is List) {
      for (final rawAction in rawActions.whereType<Map>()) {
        final action = _ChatAction.fromJson(rawAction);
        if (action != null) actions.add(action);
      }
    }

    return _ChatMessage(
      text: text,
      isUser: json['isUser'] == true,
      createdAt: createdAt,
      actions: actions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'createdAt': createdAt.toIso8601String(),
      'actions': actions.map((action) => action.toJson()).toList(),
    };
  }

  String get timeLabel {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _ChatAction {
  final String label;
  final String target;

  const _ChatAction({required this.label, required this.target});

  static _ChatAction? fromJson(Map<dynamic, dynamic> json) {
    final label = json['label']?.toString() ?? '';
    final target = json['target']?.toString() ?? '';
    if (label.trim().isEmpty || target.trim().isEmpty) return null;
    return _ChatAction(label: label, target: target);
  }

  Map<String, dynamic> toJson() {
    return {'label': label, 'target': target};
  }
}

class _ChatMemory {
  final List<Map<String, dynamic>> items;

  const _ChatMemory({required this.items});
}

class _ScoredAnswer {
  final _FaqAnswer faq;
  final int score;

  const _ScoredAnswer({required this.faq, required this.score});
}

class _FaqAnswer {
  final String question;
  final String answer;
  final List<String> keywords;

  const _FaqAnswer({
    required this.question,
    required this.answer,
    required this.keywords,
  });
}

class _FaqSection {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_FaqAnswer> questions;

  const _FaqSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.questions,
  });
}

List<_FaqSection> _faqSectionsForRole(String role) {
  final normalizedRole = role.toLowerCase();

  final baseSections = <_FaqSection>[
    const _FaqSection(
      title: 'Operacion',
      subtitle: 'Atajos para moverte por las secciones principales.',
      icon: Icons.dashboard_customize_rounded,
      questions: [
        _FaqAnswer(
          question: 'Resumen general',
          answer:
              'Puedo revisar documentos, notificaciones, solicitudes, mantenimientos y vehiculos disponibles en tu vista. Preguntame: "que tengo pendiente?" o "dame un resumen".',
          keywords: [
            'resumen',
            'estado general',
            'pendientes',
            'alertas',
            'que debo revisar',
          ],
        ),
        _FaqAnswer(
          question: 'Documentos',
          answer:
              'Entra a Documentos desde el menu principal. Alli puedes revisar archivos, estados, fechas de vencimiento y documentos asociados a vehiculos o usuarios.',
          keywords: [
            'documento',
            'documentos',
            'archivo',
            'archivos',
            'pdf',
            'vencimiento',
          ],
        ),
        _FaqAnswer(
          question: 'Documentos vencidos',
          answer:
              'Puedo consultar tus documentos y decirte cuantos aparecen vencidos. Preguntame: "que documentos tengo vencidos?" o "tengo documentos caducados?".',
          keywords: [
            'documentos vencidos',
            'vencidos',
            'caducados',
            'expirados',
            'soat vencido',
            'licencia vencida',
          ],
        ),
        _FaqAnswer(
          question: 'Documentos por vencer',
          answer:
              'Puedo revisar los documentos que vencen pronto y mostrarte los mas cercanos. Preguntame: "que documentos se vencen pronto?".',
          keywords: [
            'por vencer',
            'proximos a vencer',
            'vencen pronto',
            'por caducar',
            'por expirar',
            '30 dias',
          ],
        ),
        _FaqAnswer(
          question: 'Vehiculos',
          answer:
              'Abre Vehiculos para consultar placa, marca, modelo, propietario, conductor y accesos rapidos a documentos o mantenimientos.',
          keywords: [
            'vehiculo',
            'vehiculos',
            'placa',
            'auto',
            'carro',
            'flota',
          ],
        ),
        _FaqAnswer(
          question: 'Mis vehiculos',
          answer:
              'Puedo consultar cuantos vehiculos puedes revisar y mostrar algunas placas. Preguntame: "cuantos vehiculos tengo?".',
          keywords: [
            'mis vehiculos',
            'vehiculos asignados',
            'cuantos vehiculos',
            'placas',
            'flota',
          ],
        ),
        _FaqAnswer(
          question: 'Solicitudes',
          answer:
              'Ingresa a Solicitudes para consultar certificados, constancias, estados pendientes y el seguimiento de cada tramite.',
          keywords: [
            'solicitud',
            'solicitudes',
            'certificado',
            'certificacion',
            'constancia',
            'tramite',
          ],
        ),
        _FaqAnswer(
          question: 'Solicitudes pendientes',
          answer:
              'Puedo consultar tus solicitudes, certificados o constancias pendientes con datos reales del sistema. Prueba con: "tengo certificados pendientes?".',
          keywords: [
            'solicitudes pendientes',
            'certificados pendientes',
            'constancias pendientes',
            'tramites pendientes',
            'sin responder',
            'por aprobar',
          ],
        ),
        _FaqAnswer(
          question: 'Tipos de solicitud',
          answer:
              'Puedo consultar las opciones de solicitudes configuradas. Preguntame: "que certificados puedo pedir?" o "que tramites hay disponibles?".',
          keywords: [
            'tipos de solicitud',
            'certificados disponibles',
            'tramites disponibles',
            'puedo pedir',
            'puedo solicitar',
          ],
        ),
        _FaqAnswer(
          question: 'Mantenimientos',
          answer:
              'En Mantenimientos puedes revisar actividades sugeridas, programadas y realizadas. Tambien puedes filtrar por vehiculo cuando aplique.',
          keywords: [
            'mantenimiento',
            'mantenimientos',
            'revision',
            'taller',
            'aceite',
            'programado',
          ],
        ),
        _FaqAnswer(
          question: 'Mantenimientos programados',
          answer:
              'Puedo contar tus mantenimientos programados, sugeridos o pendientes usando la informacion del modulo Mantenimientos.',
          keywords: [
            'mantenimientos programados',
            'mantenimientos sugeridos',
            'mantenimientos pendientes',
            'revisiones programadas',
            'por hacer',
          ],
        ),
      ],
    ),
    const _FaqSection(
      title: 'Cuenta',
      subtitle: 'Perfil, notificaciones y ayuda general de la plataforma.',
      icon: Icons.manage_accounts_rounded,
      questions: [
        _FaqAnswer(
          question: 'Perfil',
          answer:
              'Ingresa a Perfil para revisar tus datos. Si algun campo no se puede editar, pide el ajuste a la empresa o al administrador responsable.',
          keywords: [
            'perfil',
            'datos',
            'correo',
            'telefono',
            'direccion',
            'cuenta',
          ],
        ),
        _FaqAnswer(
          question: 'Notificaciones',
          answer:
              'Abre Mensajes o la campana del panel superior. Alli aparecen alertas de documentos, solicitudes y mantenimientos.',
          keywords: [
            'mensaje',
            'mensajes',
            'notificacion',
            'notificaciones',
            'alerta',
            'campana',
          ],
        ),
        _FaqAnswer(
          question: 'Notificaciones sin leer',
          answer:
              'Puedo consultar cuantas notificaciones tienes sin leer y mostrarte las mas recientes. Preguntame: "cuantas notificaciones tengo?".',
          keywords: [
            'notificaciones sin leer',
            'mensajes sin leer',
            'avisos pendientes',
            'alertas nuevas',
            'cuantas notificaciones',
          ],
        ),
        _FaqAnswer(
          question: 'Soporte',
          answer:
              'Si la respuesta no esta en el asistente, contacta a TrackFile en trackfile.noreply@gmail.com o escribe por Mensajes a tu empresa.',
          keywords: [
            'soporte',
            'ayuda',
            'contacto',
            'problema',
            'error',
            'no funciona',
          ],
        ),
      ],
    ),
    const _FaqSection(
      title: 'Acceso',
      subtitle: 'Inicio de sesion, registro, roles y verificacion.',
      icon: Icons.login_rounded,
      questions: [
        _FaqAnswer(
          question: 'Que es TrackFile?',
          answer:
              'TrackFile centraliza la gestion de vehiculos, documentos, mantenimientos, solicitudes y alertas. Su objetivo es facilitar la operacion y orientar al usuario con ayuda inmediata.',
          keywords: [
            'trackfile',
            'que es',
            'para que sirve',
            'objetivo',
            'proposito',
          ],
        ),
        _FaqAnswer(
          question: 'Registro de empresa',
          answer:
              'Para registrar una empresa usa Unete, completa los datos solicitados y adjunta el RUT en PDF. Luego revisa el correo de verificacion.',
          keywords: [
            'registro',
            'registrarme',
            'empresa',
            'rut',
            'unirme',
            'unete',
          ],
        ),
        _FaqAnswer(
          question: 'Roles de usuario',
          answer:
              'Los roles principales son Empresa, Propietario y Conductor. Cada uno tiene permisos y vistas diferentes segun sus responsabilidades.',
          keywords: ['rol', 'roles', 'empresa', 'propietario', 'conductor'],
        ),
      ],
    ),
    const _FaqSection(
      title: 'Tramites',
      subtitle: 'Orientacion sobre solicitudes, seguimiento y recordatorios.',
      icon: Icons.assignment_turned_in_rounded,
      questions: [
        _FaqAnswer(
          question: 'Como hago un tramite?',
          answer:
              'Entra a Solicitudes, selecciona el tipo de tramite disponible, agrega la descripcion y envia la solicitud. Luego revisa el seguimiento en la misma seccion.',
          keywords: [
            'tramite',
            'tramites',
            'proceso',
            'procedimiento',
            'solicitar',
            'pedir',
          ],
        ),
        _FaqAnswer(
          question: 'Recordatorios de vencimiento',
          answer:
              'Revisa Inicio, Mensajes y Documentos para ver documentos vencidos o proximos a vencer. Las alertas dependen de que cada documento tenga fecha de vencimiento registrada.',
          keywords: [
            'recordatorio',
            'recordatorios',
            'vencimiento',
            'vencer',
            'vencido',
            'expira',
            'caduca',
          ],
        ),
        _FaqAnswer(
          question: 'Seguimiento de solicitudes',
          answer:
              'En Solicitudes puedes consultar estado, fecha de envio, historial y respuesta de la empresa. Ese modulo centraliza el seguimiento del tramite.',
          keywords: [
            'seguimiento',
            'estado',
            'pendiente',
            'aprobado',
            'rechazado',
            'historial',
          ],
        ),
      ],
    ),
  ];

  if (normalizedRole.contains('empresa')) {
    return [
      ...baseSections,
      const _FaqSection(
        title: 'Empresa',
        subtitle: 'Gestion de personas, documentos y vehiculos de la empresa.',
        icon: Icons.apartment_rounded,
        questions: [
          _FaqAnswer(
            question: 'Conductores',
            answer:
                'Entra a Conductores desde el menu. Puedes consultar personas, vehiculos asignados, documentos, certificados y mantenimientos relacionados.',
            keywords: [
              'conductor',
              'conductores',
              'persona',
              'personas',
              'empleado',
            ],
          ),
          _FaqAnswer(
            question: 'Propietarios',
            answer:
                'Abre Propietarios para revisar informacion asociada, vehiculos, documentos y solicitudes relacionadas con cada propietario.',
            keywords: [
              'propietario',
              'propietarios',
              'dueno',
              'dueño',
              'owner',
            ],
          ),
          _FaqAnswer(
            question: 'Subir documentos',
            answer:
                'Ve a Documentos. Si estas en la vista general de empresa, usa el boton de carga para registrar nuevos documentos y asociarlos correctamente.',
            keywords: [
              'subir',
              'cargar',
              'crear documento',
              'nuevo documento',
              'adjuntar',
            ],
          ),
        ],
      ),
    ];
  }

  if (normalizedRole.contains('propietario')) {
    return [
      ...baseSections,
      const _FaqSection(
        title: 'Propietario',
        subtitle: 'Consultas frecuentes para tus vehiculos y solicitudes.',
        icon: Icons.badge_rounded,
        questions: [
          _FaqAnswer(
            question: 'Mis vehiculos',
            answer:
                'Abre Vehiculos en el menu superior. Alli encontraras tus vehiculos asociados y accesos a documentos o mantenimientos por placa.',
            keywords: [
              'mis vehiculos',
              'vehiculo',
              'vehiculos',
              'flota',
              'placa',
            ],
          ),
          _FaqAnswer(
            question: 'Documentos de mi vehiculo',
            answer:
                'Desde Vehiculos puedes entrar a Documentos para ver los archivos asociados a una placa especifica.',
            keywords: [
              'documentos vehiculo',
              'soat',
              'tecnomecanica',
              'tarjeta',
              'poliza',
            ],
          ),
          _FaqAnswer(
            question: 'Estado de solicitudes',
            answer:
                'Ve a Solicitudes para revisar el estado de certificados, constancias y tramites asociados a tu usuario.',
            keywords: [
              'estado',
              'seguimiento',
              'solicitud',
              'solicitudes',
              'pedir',
            ],
          ),
        ],
      ),
    ];
  }

  if (normalizedRole.contains('conductor')) {
    return [
      ...baseSections,
      const _FaqSection(
        title: 'Conductor',
        subtitle: 'Accesos rapidos para vehiculo asignado y mantenimientos.',
        icon: Icons.local_shipping_rounded,
        questions: [
          _FaqAnswer(
            question: 'Mi vehiculo asignado',
            answer:
                'Abre Vehiculo en el menu superior para consultar la placa asignada y sus accesos a documentos o mantenimientos.',
            keywords: ['mi vehiculo', 'asignado', 'placa', 'vehiculo asignado'],
          ),
          _FaqAnswer(
            question: 'Reportar mantenimiento',
            answer:
                'Entra a Mantenimientos para revisar actividades preventivas, correctivas y registros asociados a tu vehiculo.',
            keywords: [
              'reportar',
              'mantenimiento',
              'mantenimientos',
              'revision',
            ],
          ),
          _FaqAnswer(
            question: 'Mis solicitudes',
            answer:
                'Ingresa a Solicitudes para revisar certificados, constancias y el estado de cada solicitud relacionada con tu usuario.',
            keywords: [
              'mis solicitudes',
              'solicitud',
              'solicitudes',
              'certificado',
            ],
          ),
        ],
      ),
    ];
  }

  return baseSections;
}
