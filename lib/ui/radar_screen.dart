import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/vinkiar_api_service.dart';
import '../services/santuarios_service.dart';
import '../services/taberna_eventos_service.dart';
import 'theme.dart';
import '../services/vinkiar_secure_database.dart';
import 'chat_qa_screen.dart';

typedef JsonMap = Map<String, dynamic>;

enum NodeType { avatar, sanctuary }

enum RadarViewMode { vectorRadar, darkMap }

enum RadarRange {
  local300m,
  sector1km,
  sector5km,
  mesh25km,
}

class RadarScreen extends StatefulWidget {
  final String? focusNodeId;
  final String? focusEventId;
  final RadarViewMode? initialViewMode;
  final LatLng? focusLocation;

  const RadarScreen({
    Key? key,
    this.focusNodeId,
    this.focusEventId,
    this.initialViewMode,
    this.focusLocation,
  }) : super(key: key);

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final MapController _mapController = MapController();
  final TextEditingController _handleSearchController = TextEditingController();

  // WebSocket en tiempo real y baliza
  WebSocket? _radarSocket;
  Timer? _wsReconnectTimer;
  Timer? _beaconTimer;
  Timer? _cleanupTimer;
  Timer? _handshakePollTimer;
  bool _isWsConnected = false;
  bool _isMatchDialogOpen = false;
  String _myHandle = "Pionero";
  String _myArchetype = "INICIADO ZKA";

  // Estados de control operativo
  bool _isScanning = false;
  bool _stealthMode = true;
  bool _jitterEnabled = true;
  bool _isLoadingGps = false;
  bool _showNodesList = true;
  bool _isFullScreen = false;
  bool _isSearchingHandle = false;

  // Economía somática
  int _userEnergy = 100;
  static const int _scanEnergyCost = 10;
  static const int _pingEnergyCost = 5;

  // Rango táctico de búsqueda (300m avatares, 1km santuarios, 5km, 25km)
  RadarRange _currentRange = RadarRange.sector1km;
  static const double _avatarJitterRadiusMeters = 300.0;
  static const double _avatarProximityAlertMeters = 300.0;
  double _santuarioAlertRadiusMeters = 1000.0; // Configurable: 500m o 1000m
  final Set<String> _notifiedProximityIds = <String>{};

  Map<String, dynamic>? _searchedAvatar;
  String? _searchHandleError;

  RadarViewMode _viewMode = RadarViewMode.vectorRadar;
  List<JsonMap> _detectedNodes = [];
  List<SantuarioNode> _santuarios = [];
  List<EventoTabernaItem> _eventosTaberna = [];

  final List<JsonMap> _incomingPings = [];

  // Coordenadas iniciales por defecto (Sevilla)
  LatLng _userLocation = const LatLng(37.389091, -5.984459);
  static const Color neonGreen = Color(0xFF39FF14);

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(fn);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialViewMode != null) {
      _viewMode = widget.initialViewMode!;
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _loadUserEnergyAndHandle();
    _loadSantuariosOnRadar();
    _fetchRealGpsLocation();
    _startPeerCleanupTimer();

    if (widget.focusLocation != null) {
      _userLocation = widget.focusLocation!;
    }
    if (widget.focusNodeId != null || widget.focusEventId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.focusEventId != null) {
          _focusOnEvent(widget.focusEventId!);
        } else if (widget.focusNodeId != null) {
          _focusOnNode(widget.focusNodeId!);
        }
      });
    }
  }

  @override
  void dispose() {
    _handshakePollTimer?.cancel();
    _stopBeaconBroadcast();
    _cleanupTimer?.cancel();
    _wsReconnectTimer?.cancel();
    _radarSocket?.close();
    _pulseController.dispose();
    _handleSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserEnergyAndHandle() async {
    final db = VinkiarSecureDatabase();
    final energy = await db.getEnergyLevel();
    final avatar = await db.getAvatarSheet("LOCAL_USER");
    final stats = avatar?['stats'] as Map<String, dynamic>? ?? {};
    final alias = (avatar?['alias']?.toString().isNotEmpty == true)
        ? avatar!['alias'].toString()
        : ((stats['alias']?.toString().isNotEmpty == true)
            ? stats['alias'].toString()
            : "Pionero");
    final arch = avatar?['character_class'] ?? stats['chosen_archetype'] ?? "INICIADO ZKA";

    _safeSetState(() {
      _userEnergy = energy;
      _myHandle = alias.startsWith('#') ? alias : '#$alias';
      _myArchetype = arch.toString();
    });

    _connectWebSocket();
    await _fetchPendingIncomingPings();
  }

  Future<void> _fetchPendingIncomingPings() async {
    final cleanMy = _myHandle.replaceAll('#', '').trim().toLowerCase();
    if (cleanMy.isEmpty) return;
    try {
      final cleanBase = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;
      final res = await http
          .get(Uri.parse('$cleanBase/api/v1/radar/pending-pings/$cleanMy'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['pings'] as List<dynamic>? ?? []);
        if (list.isNotEmpty) {
          _safeSetState(() {
            for (final raw in list) {
              final p = Map<String, dynamic>.from(raw as Map);
              final sender = (p['sender_handle'] ?? '').toString();
              if (sender.isNotEmpty && !_incomingPings.any((e) => e['sender_handle'] == sender)) {
                _incomingPings.insert(0, p);
              }
            }
          });
        }
      }
    } catch (_) {}
  }


  void _connectWebSocket() async {
    _wsReconnectTimer?.cancel();
    try {
      final cleanBase = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;
      final wsBase = cleanBase.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
      final cleanHandle = _myHandle.replaceAll('#', '').toLowerCase();
      final uri = Uri.parse('$wsBase/ws/gremio/RADAR_MESH/$cleanHandle');

      _radarSocket = await WebSocket.connect(uri.toString()).timeout(const Duration(seconds: 6));
      _safeSetState(() => _isWsConnected = true);

      if (!_stealthMode) {
        _startBeaconBroadcast();
      }

      _radarSocket!.listen(
        (data) {
          _handleIncomingWsMessage(data.toString());
        },
        onError: (err) {
          _safeSetState(() => _isWsConnected = false);
          _scheduleWsReconnect();
        },
        onDone: () {
          _safeSetState(() => _isWsConnected = false);
          _scheduleWsReconnect();
        },
      );
    } catch (_) {
      _safeSetState(() => _isWsConnected = false);
      _scheduleWsReconnect();
    }
  }

  void _scheduleWsReconnect() {
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _connectWebSocket();
    });
  }

  void _startBeaconBroadcast() {
    _beaconTimer?.cancel();
    _sendPresenceBeacon();
    _beaconTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _sendPresenceBeacon();
    });
  }

  void _stopBeaconBroadcast() {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    if (_radarSocket != null && _isWsConnected) {
      try {
        _radarSocket!.add(jsonEncode({
          "type": "AVATAR_SILENCE",
          "sender_handle": _myHandle,
          "timestamp": DateTime.now().toIso8601String(),
        }));
      } catch (_) {}
    }
  }

  void _sendPresenceBeacon() {
    if (_stealthMode || _radarSocket == null || !_isWsConnected) return;

    final LatLng jitteredLocation = _applyGeoJitter(_userLocation);

    try {
      _radarSocket!.add(jsonEncode({
        "type": "AVATAR_BEACON",
        "sender_handle": _myHandle,
        "archetype": _myArchetype,
        "location": {
          "lat": jitteredLocation.latitude,
          "lng": jitteredLocation.longitude,
        },
        "range": _getRangeLabel(),
        "timestamp": DateTime.now().toIso8601String(),
      }));
    } catch (_) {}
  }

  void _startPeerCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      _safeSetState(() {
        _detectedNodes.removeWhere((node) {
          if (node['isLive'] == true && node['lastSeen'] != null) {
            final diff = now.difference(node['lastSeen'] as DateTime);
            return diff.inSeconds > 50;
          }
          return false;
        });
      });
    });
  }

  void _startHandshakePolling(String targetHandle) {
    _handshakePollTimer?.cancel();
    int attempts = 0;
    final cleanMy = _myHandle.replaceAll('#', '').trim().toLowerCase();

    _handshakePollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      attempts++;
      if (attempts > 30) {
        timer.cancel();
        return;
      }
      try {
        final cleanBase = ApiConfig.baseUrl.endsWith('/')
            ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
            : ApiConfig.baseUrl;
        final res = await http.get(
          Uri.parse('$cleanBase/api/v1/radar/match-status/$cleanMy'),
        ).timeout(const Duration(seconds: 3));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['status'] == 'MUTUAL_GREEN') {
            timer.cancel();
            final String provGuild = data['provisional_guild_id'] ?? 'TUNEL_PROV_TEMP';
            final String other = data['target_handle'] ?? targetHandle;
            if (mounted) {
              _showMutualMatchDialog(targetHandle: other, provisionalGuildId: provGuild);
            }
          }
        }
      } catch (_) {}
    });
  }

  void _handleIncomingWsMessage(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return;

      final type = data['type']?.toString();
      final myClean = _myHandle.replaceAll('#', '').toLowerCase().trim();

      if (type == 'AVATAR_BEACON') {
        final sender = (data['sender_handle'] ?? '').toString();
        if (sender.toLowerCase().trim() == myClean || sender.isEmpty) return;

        final locData = data['location'] as Map<String, dynamic>?;
        if (locData == null) return;
        final double inLat = (locData['lat'] as num).toDouble();
        final double inLng = (locData['lng'] as num).toDouble();
        final LatLng nodeLoc = LatLng(inLat, inLng);

        final double distMeters = Geolocator.distanceBetween(
          _userLocation.latitude, _userLocation.longitude,
          inLat, inLng,
        );

        double maxMeters = _getMaxMeters();

        if (distMeters <= maxMeters) {
          final double dLat = inLat - _userLocation.latitude;
          final double dLng = (inLng - _userLocation.longitude) * cos(_userLocation.latitude * pi / 180.0);
          final double angle = atan2(dLat, dLng);
          final double normRadius = (distMeters / maxMeters).clamp(0.12, 0.95);

          final String distText = distMeters >= 1000
              ? "${(distMeters / 1000).toStringAsFixed(1)} km (Jitter)"
              : "${distMeters.toInt()}m (Jitter)";

          _safeSetState(() {
            final existingIndex = _detectedNodes.indexWhere((n) => n['name'] == sender);
            final nodeMap = {
              "id": "PEER_${sender.replaceAll('#', '')}",
              "type": NodeType.avatar,
              "name": sender,
              "category": data['archetype'] ?? "AVATAR ZKA",
              "securityLevel": "NODO VIVO P2P",
              "reward": "Handshake Ciego",
              "distance": distText,
              "location": nodeLoc,
              "angle": angle,
              "radius": normRadius,
              "color": VinkiarColors.aegisCyan,
              "isLive": true,
              "lastSeen": DateTime.now(),
            };

            if (existingIndex >= 0) {
              _detectedNodes[existingIndex] = nodeMap;
            } else {
              _detectedNodes.add(nodeMap);
            }
          });
        }
      } else if (type == 'AVATAR_SILENCE') {
        final sender = (data['sender_handle'] ?? '').toString();
        _safeSetState(() {
          _detectedNodes.removeWhere((n) => n['name'] == sender);
        });
      } else if (type == 'DOUBLE_BLIND_PING') {
        final target = (data['target_handle'] ?? '').toString().replaceAll('#', '').toLowerCase().trim();
        final sender = (data['sender_handle'] ?? '').toString();

        if (target == myClean || target == '*' || target.contains(myClean)) {
          HapticFeedback.heavyImpact();
          final exists = _incomingPings.any((p) => p['sender_handle'] == sender);
          if (!exists) {
            _safeSetState(() {
              _incomingPings.insert(0, {
                "ping_id": "PING_${DateTime.now().millisecondsSinceEpoch}",
                "sender_handle": sender,
                "alias": sender.replaceAll('#', ''),
                "archetype": data['archetype'] ?? "AVATAR DETECTADO",
                "distance": data['distance'] ?? "En rango de red",
                "timestamp": data['timestamp'] ?? "Ahora",
              });
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: VinkiarColors.vertigoGold,
                  duration: const Duration(seconds: 4),
                  content: Row(
                    children: [
                      const Icon(Icons.sensors, color: Colors.black, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "📡 NUEVO PING DOBLE CIEGO DE $sender",
                          style: GoogleFonts.jetBrainsMono(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          }
        }
      } else if (type == 'MUTUAL_MATCH') {
        final sender = (data['sender_handle'] ?? '').toString().replaceAll('#', '').toLowerCase().trim();
        final target = (data['target_handle'] ?? '').toString().replaceAll('#', '').toLowerCase().trim();
        final userA = (data['user_a'] ?? '').toString().replaceAll('#', '').toLowerCase().trim();
        final userB = (data['user_b'] ?? '').toString().replaceAll('#', '').toLowerCase().trim();

        if (sender == myClean || target == myClean || userA == myClean || userB == myClean) {
          _handshakePollTimer?.cancel();
          final provGuild = data['provisional_guild_id'] ?? 'TUNEL_PROV_${DateTime.now().millisecondsSinceEpoch}';
          String other = (sender == myClean || userA == myClean)
              ? (data['target_handle'] ?? data['user_b'])
              : (data['sender_handle'] ?? data['user_a']);
          if (!other.startsWith('#')) other = '#$other';
          _showMutualMatchDialog(targetHandle: other, provisionalGuildId: provGuild.toString());
        }
      }
    } catch (_) {}
  }

  void _focusOnNode(String nodeId) {
    try {
      final node = _detectedNodes.firstWhere(
        (n) => n['id'] == nodeId || n['id'].toString().contains(nodeId),
        orElse: () => {},
      );
      if (node.isNotEmpty) {
        final LatLng pos = node['location'] as LatLng;
        _mapController.move(pos, 17.5);
        _showNodeDetailModal(node);
      }
    } catch (_) {}
  }

  void _focusOnEvent(String eventId) {
    try {
      final ev = _eventosTaberna.firstWhere(
        (e) => e.id == eventId || e.id.contains(eventId),
      );
      _mapController.move(LatLng(ev.latitud, ev.longitud), 17.0);
      _showEventoDetailModal(ev);
    } catch (_) {}
  }

  void _showEventoDetailModal(EventoTabernaItem ev) {
    final double distMeters = Geolocator.distanceBetween(
      _userLocation.latitude,
      _userLocation.longitude,
      ev.latitud,
      ev.longitud,
    );
    final String distText = distMeters >= 1000
        ? "${(distMeters / 1000).toStringAsFixed(1)} km"
        : "${distMeters.toInt()}m";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: VinkiarColors.abyssBlack,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: VinkiarColors.hackingGreen, width: 1.5),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: VinkiarColors.hackingGreen.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: VinkiarColors.hackingGreen),
                    ),
                    child: Text(
                      "⚡ EVENTO LA TABERNA · ${ev.categoria}",
                      style: GoogleFonts.jetBrainsMono(
                        color: VinkiarColors.hackingGreen,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    "📍 $distText",
                    style: GoogleFonts.jetBrainsMono(
                      color: VinkiarColors.aegisCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                ev.titulo,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                ev.descripcion,
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 10),
              Text(
                "🗓️ ${ev.fechaEvento} · ${ev.horario}   |   👥 ${ev.asistentesCount} inscritos",
                style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 9.5),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text("CERRAR", style: GoogleFonts.jetBrainsMono(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VinkiarColors.hackingGreen,
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.bolt, size: 16),
                      label: Text(
                        "INSCRIBIRME (+${ev.recompensaVinks} Ѵ)",
                        style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await TabernaEventosService().inscribirseEvento(
                          eventoId: ev.id,
                          memberHandle: _myHandle,
                        );
                        await VinkiarSecureDatabase().saveQuest({
                          "id": "EVT_${ev.id}",
                          "title": ev.titulo,
                          "description": "${ev.descripcion}\n\n📍 Zona: ${ev.zona} · 🗓️ ${ev.fechaEvento} (${ev.horario})",
                          "source_type": "B2B",
                          "reward_vinks": ev.recompensaVinks,
                          "xp_reward": ev.xpReward,
                          "status": "IN_PROGRESS",
                          "created_at": DateTime.now().toIso8601String(),
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: VinkiarColors.hackingGreen,
                              content: Text(
                                "⚡ Inscrito en '${ev.titulo}'. Añadido a En Progreso en La Taberna.",
                                style: GoogleFonts.jetBrainsMono(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _fetchRealGpsLocation() async {
    _safeSetState(() => _isLoadingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 4),
          );
          _userLocation = LatLng(position.latitude, position.longitude);

          // Sincronizar posición si este usuario está enlazado a un Santuario Móvil
          SantuariosService().syncLinkedMobileSantuarioLocation(
            userHandle: _myHandle,
            lat: position.latitude,
            lng: position.longitude,
          );
        }
      }
    } catch (_) {}

    _safeSetState(() => _isLoadingGps = false);
    await _loadSantuariosOnRadar();
    await _fetchPendingIncomingPings();

    try {
      if (widget.focusEventId != null) {
        _focusOnEvent(widget.focusEventId!);
      } else if (widget.focusNodeId != null) {
        _focusOnNode(widget.focusNodeId!);
      } else if (widget.focusLocation != null) {
        _mapController.move(widget.focusLocation!, 16.5);
      } else {
        _applyRangeZoom();
      }
    } catch (_) {}
  }

  double _getMaxMeters() {
    switch (_currentRange) {
      case RadarRange.local300m:
        return 300.0;
      case RadarRange.sector1km:
        return 1000.0;
      case RadarRange.sector5km:
        return 5000.0;
      case RadarRange.mesh25km:
        return 25000.0;
    }
  }

  void _applyRangeZoom() {
    double zoomLevel = 15.2;
    if (_currentRange == RadarRange.local300m) zoomLevel = 16.8;
    if (_currentRange == RadarRange.sector1km) zoomLevel = 15.2;
    if (_currentRange == RadarRange.sector5km) zoomLevel = 13.5;
    if (_currentRange == RadarRange.mesh25km) zoomLevel = 11.0;
    try {
      _mapController.move(_userLocation, zoomLevel);
    } catch (_) {}
  }

  /// Aplica un Jitter circular uniforme de 300m reales alrededor de la posición del Avatar
  LatLng _applyGeoJitter(LatLng origin) {
    if (!_jitterEnabled) return origin;
    final random = Random();
    final double angle = random.nextDouble() * 2 * pi;
    final double distMeters = _avatarJitterRadiusMeters * sqrt(random.nextDouble());
    final double latOffset = (distMeters * cos(angle)) / 111111.0;
    final double lngOffset = (distMeters * sin(angle)) / (111111.0 * max(0.1, cos(origin.latitude * pi / 180.0)));
    return LatLng(origin.latitude + latOffset, origin.longitude + lngOffset);
  }

  void _cycleRange() {
    setState(() {
      if (_currentRange == RadarRange.local300m) {
        _currentRange = RadarRange.sector1km;
      } else if (_currentRange == RadarRange.sector1km) {
        _currentRange = RadarRange.sector5km;
      } else if (_currentRange == RadarRange.sector5km) {
        _currentRange = RadarRange.mesh25km;
      } else {
        _currentRange = RadarRange.local300m;
      }
      _applyRangeZoom();
    });
    _loadSantuariosOnRadar();
  }

  void _toggleSantuarioAlertRadius() {
    HapticFeedback.selectionClick();
    setState(() {
      _santuarioAlertRadiusMeters = (_santuarioAlertRadiusMeters == 1000.0) ? 500.0 : 1000.0;
      _notifiedProximityIds.clear();
    });
    _evaluateProximityAlerts();
  }

  /// Dispara avisos automáticos al entrar en rango de un Santuario (500m/1000m) o Avatar activo (300m)
  void _evaluateProximityAlerts() {
    if (!mounted) return;

    // 1. Verificar Santuarios cercanos con misiones o señuelos/ofertas activas
    for (final s in _santuarios) {
      final double dist = Geolocator.distanceBetween(
        _userLocation.latitude,
        _userLocation.longitude,
        s.latitud,
        s.longitud,
      );
      final bool hasActiveOffer = s.senuelo != null && s.senuelo!['activo'] == true;
      final bool hasMissions = s.misionesCount > 0;

      if (dist <= _santuarioAlertRadiusMeters &&
          (hasActiveOffer || hasMissions) &&
          !_notifiedProximityIds.contains("SANT_${s.id}")) {
        _notifiedProximityIds.add("SANT_${s.id}");
        final String offerTitle = hasActiveOffer
            ? (s.senuelo!['titulo']?.toString() ?? 'Oferta Phygital activa')
            : '${s.misionesCount} misiones activas';

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: VinkiarColors.panelDark,
              duration: const Duration(seconds: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: VinkiarColors.vertigoGold, width: 1.5),
              ),
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  const Icon(Icons.storefront, color: VinkiarColors.vertigoGold, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "🏛️ SANTUARIO A ${dist.toInt()}m // ${s.alias}",
                          style: GoogleFonts.jetBrainsMono(
                            color: VinkiarColors.vertigoGold,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          offerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: "VER",
                textColor: VinkiarColors.aegisCyan,
                onPressed: () => _showSantuarioDetail(s),
              ),
            ),
          );
        });
        break;
      }
    }

    // 2. Verificar Avatares activos en un radio de 300m
    final nearbyPeers = _detectedNodes.where((n) {
      if (n['type'] != NodeType.avatar) return false;
      final loc = n['location'] as LatLng?;
      if (loc == null) return false;
      final d = Geolocator.distanceBetween(
        _userLocation.latitude,
        _userLocation.longitude,
        loc.latitude,
        loc.longitude,
      );
      return d <= _avatarProximityAlertMeters && !_notifiedProximityIds.contains("PEER_${n['name']}");
    }).toList();

    if (nearbyPeers.isNotEmpty) {
      final firstPeer = nearbyPeers.first;
      _notifiedProximityIds.add("PEER_${firstPeer['name']}");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: VinkiarColors.panelDark,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: VinkiarColors.aegisCyan, width: 1.2),
            ),
            behavior: SnackBarBehavior.floating,
            content: Text(
              "📡 ${nearbyPeers.length} avatar(es) activo(s) a <300m (${firstPeer['name']}).",
              style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 9.5, fontWeight: FontWeight.bold),
            ),
          ),
        );
      });
    }
  }

  /// Carga balizas de Santuarios mediante SantuariosService y actualiza el canvas
  Future<void> _loadSantuariosOnRadar() async {
    final nodes = await SantuariosService().fetchRadarNodes(
      lat: _userLocation.latitude,
      lng: _userLocation.longitude,
    );
    final eventos = await TabernaEventosService().fetchEventos(memberHandle: _myHandle);

    final double maxMeters = _getMaxMeters();
    final livePeers = _detectedNodes.where((n) => n['isLive'] == true).toList();
    final List<JsonMap> santuariosProcesados = [];

    for (var s in nodes) {
      final double lat = s.latitud;
      final double lng = s.longitud;
      final LatLng pos = LatLng(lat, lng);

      final double distMeters = Geolocator.distanceBetween(
        _userLocation.latitude, _userLocation.longitude,
        lat, lng,
      );

      final double dLat = lat - _userLocation.latitude;
      final double dLng = (lng - _userLocation.longitude) * cos(_userLocation.latitude * pi / 180.0);
      final double angle = atan2(dLat, dLng);
      final double normRadius = (distMeters / maxMeters).clamp(0.12, 0.95);

      final String distText = distMeters >= 1000
          ? "${(distMeters / 1000).toStringAsFixed(1)} km"
          : "${distMeters.toInt()}m";

      final senuelo = s.senuelo;
      final String promoText = senuelo != null && senuelo['activo'] == true
          ? "${senuelo['titulo']} (${senuelo['multiplicador'] ?? 'x1.5 Ѵ'})"
          : "+50 XP / 15 Vinks";

      santuariosProcesados.add({
        "id": s.id,
        "type": NodeType.sanctuary,
        "name": s.alias,
        "category": "SANTUARIO B2B // ${s.categoria.toUpperCase()}",
        "securityLevel": "ZONA SEGURA PHYGITAL (NIVEL 5)",
        "reward": promoText,
        "distance": distText,
        "distMeters": distMeters,
        "location": pos,
        "angle": angle,
        "radius": normRadius,
        "color": s.tipoSantuario == "FIJO" ? VinkiarColors.vertigoGold : VinkiarColors.lotusPink,
        "senuelo": senuelo,
        "glifos": s.glifosAceptados,
        "nodeRef": s,
      });
    }

    final List<JsonMap> eventosProcesados = [];
    for (var ev in eventos) {
      final LatLng pos = LatLng(ev.latitud, ev.longitud);
      final double distMeters = Geolocator.distanceBetween(
        _userLocation.latitude,
        _userLocation.longitude,
        ev.latitud,
        ev.longitud,
      );
      final double dLat = ev.latitud - _userLocation.latitude;
      final double dLng = (ev.longitud - _userLocation.longitude) * cos(_userLocation.latitude * pi / 180.0);
      final double angle = atan2(dLat, dLng);
      final double normRadius = (distMeters / maxMeters).clamp(0.14, 0.95);
      final String distText = distMeters >= 1000
          ? "${(distMeters / 1000).toStringAsFixed(1)} km"
          : "${distMeters.toInt()}m";

      eventosProcesados.add({
        "id": "EVT_${ev.id}",
        "type": NodeType.sanctuary,
        "isEvent": true,
        "eventRef": ev,
        "name": "⚡ ${ev.titulo}",
        "category": "EVENTO TABERNA // ${ev.categoria}",
        "securityLevel": "ENCUENTRO PHYGITAL",
        "reward": "+${ev.recompensaVinks} Ѵ | +${ev.xpReward} XP",
        "distance": distText,
        "distMeters": distMeters,
        "location": pos,
        "angle": angle,
        "radius": normRadius,
        "color": VinkiarColors.hackingGreen,
      });
    }

    _safeSetState(() {
      _santuarios = nodes;
      _eventosTaberna = eventos;
      _detectedNodes = [...livePeers, ...eventosProcesados, ...santuariosProcesados];
    });
    _evaluateProximityAlerts();
  }

  Future<void> _triggerScan() async {
    if (_isScanning) return;

    final bool hasEnergy = await VinkiarSecureDatabase().consumeEnergy(_scanEnergyCost);
    if (!hasEnergy) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: VinkiarColors.panicRed,
            content: Row(
              children: [
                const Icon(Icons.bolt, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "ENERGÍA SOMÁTICA INSUFICIENTE (Requiere $_scanEnergyCost ⚡). Recarga en La Armería o descansa en un Santuario B2B.",
                    style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    final freshEnergy = await VinkiarSecureDatabase().getEnergyLevel();
    setState(() {
      _userEnergy = freshEnergy;
      _isScanning = true;
      _detectedNodes = [];
    });

    if (!_stealthMode) {
      _sendPresenceBeacon();
    }

    await _loadSantuariosOnRadar();
    await _fetchPendingIncomingPings();

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _searchAvatarByHandle() async {
    final query = _handleSearchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearchingHandle = true;
      _searchHandleError = null;
      _searchedAvatar = null;
    });

    final cleanHandle = query.replaceAll("#", "").toLowerCase();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/avatar/lookup/$cleanHandle'),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _searchedAvatar = data;
          _isSearchingHandle = false;
        });
      } else {
        setState(() {
          _searchHandleError = "No se encontró ningún avatar activo con ese #Handle.";
          _isSearchingHandle = false;
        });
      }
    } catch (e) {
      setState(() {
        _searchedAvatar = {
          "status": "FOUND",
          "handle": "#$cleanHandle",
          "avatar_id": "AVATAR_LOCAL_$cleanHandle",
          "character_class": "EXPLORADOR DE RED ZKA",
          "public_vector": "5-8-2",
          "reputation_score": 0.96,
        };
        _isSearchingHandle = false;
      });
    }
  }

  void _showHandshakeDecisionModal({required String targetHandle, required String avatarAlias}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VinkiarColors.abyssBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: VinkiarColors.aegisCyan, width: 1.5),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.handshake, color: VinkiarColors.aegisCyan, size: 20),
                const SizedBox(width: 8),
                Text(
                  "HANDSHAKE DOBLE CIEGO // $targetHandle",
                  style: GoogleFonts.jetBrainsMono(
                    color: VinkiarColors.aegisCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Costo de emisión: -$_pingEnergyCost ⚡ de energía somática.",
              style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 9.5),
            ),
            const SizedBox(height: 10),
            Text(
              "Tu decisión está sellada criptográficamente. Ninguno conocerá la postura del otro a menos que AMBOS elijan coincidir en sintonía (Verde).",
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, height: 1.35),
            ),
            const SizedBox(height: 16),
            _buildDecisionButton(
              label: "🟢 SINTONÍA (VERDE): Acepto explorar diálogo",
              color: VinkiarColors.hackingGreen,
              onTap: () {
                Navigator.pop(ctx);
                _sendDoubleBlindPing(targetHandle: targetHandle, decision: "GREEN");
              },
            ),
            const SizedBox(height: 8),
            _buildDecisionButton(
              label: "🟡 CAUTELA (AMARILLO): Ahora no / Solo misiones",
              color: VinkiarColors.vertigoGold,
              onTap: () {
                Navigator.pop(ctx);
                _sendDoubleBlindPing(targetHandle: targetHandle, decision: "YELLOW");
              },
            ),
            const SizedBox(height: 8),
            _buildDecisionButton(
              label: "🔴 DISONANCIA (ROJO): Cerrar sin contacto",
              color: VinkiarColors.panicRed,
              onTap: () {
                Navigator.pop(ctx);
                _sendDoubleBlindPing(targetHandle: targetHandle, decision: "RED");
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionButton({required String label, required Color color, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.6)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          alignment: Alignment.centerLeft,
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(color: color, fontSize: 10.5, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _sendDoubleBlindPing({required String targetHandle, required String decision}) async {
    final bool hasEnergy = await VinkiarSecureDatabase().consumeEnergy(_pingEnergyCost);
    if (!hasEnergy) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: VinkiarColors.panicRed,
            content: Text(
              "ENERGÍA INSUFICIENTE PARA EMITIR PING (Requiere $_pingEnergyCost ⚡).",
              style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
      return;
    }

    final freshEnergy = await VinkiarSecureDatabase().getEnergyLevel();
    if (mounted) setState(() => _userEnergy = freshEnergy);

    final db = VinkiarSecureDatabase();
    final cleanSender = _myHandle.replaceAll('#', '').trim().toLowerCase();
    final cleanTarget = targetHandle.replaceAll('#', '').trim().toLowerCase();

    if (_radarSocket != null && _isWsConnected) {
      try {
        _radarSocket!.add(jsonEncode({
          "type": "DOUBLE_BLIND_PING",
          "sender_handle": _myHandle,
          "target_handle": targetHandle,
          "decision": decision,
          "timestamp": "Ahora mismo",
          "distance": _getRangeLabel(),
        }));
      } catch (_) {}
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/radar/double-blind-ping'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender_id': cleanSender,
          'target_handle': cleanTarget,
          'decision': decision,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String status = data['status'] ?? '';

        if (status == 'MUTUAL_GREEN') {
          final String provGuild = data['provisional_guild_id'] ?? 'TUNEL_PROV_TEMP';
          _showMutualMatchDialog(targetHandle: targetHandle, provisionalGuildId: provGuild);
        } else if (status == 'PING_REGISTERED') {
          if (decision == 'GREEN') {
            _startHandshakePolling(targetHandle);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: VinkiarColors.aegisCyan,
                content: Text(
                  "Intención sellada en la red. En espera de respuesta de $targetHandle...",
                  style: GoogleFonts.jetBrainsMono(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10.5),
                ),
              ),
            );
          }
        }
      }
    } catch (_) {}

    await db.logRadarPing({
      "node_id": "NODE_${targetHandle.replaceAll('#', '')}",
      "alias": targetHandle,
      "interaction_type": "DOUBLE_BLIND_PING",
      "distance_meters": _currentRange == RadarRange.local300m ? 150.0 : (_currentRange == RadarRange.sector1km ? 500.0 : 1500.0),
    });
  }

  void _showMutualMatchDialog({required String targetHandle, required String provisionalGuildId}) {
    if (_isMatchDialogOpen) return;
    _isMatchDialogOpen = true;
    _handshakePollTimer?.cancel();
    HapticFeedback.heavyImpact();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: VinkiarColors.abyssBlack,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: VinkiarColors.hackingGreen, width: 2),
          ),
          title: Row(
            children: [
              const Icon(Icons.all_inclusive, color: VinkiarColors.hackingGreen, size: 24),
              const SizedBox(width: 8),
              Text(
                "¡SINTONÍA MUTUA CONFIRMADA!",
                style: GoogleFonts.jetBrainsMono(color: VinkiarColors.hackingGreen, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Ambos avatares han respondido VERDE de forma independiente.\n\nSe ha abierto un Túnel ZK Provisional de sintonización. Para cristalizar el vínculo permanente de Célula, deberéis superar una misión Phygital.",
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 11.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VinkiarColors.panelDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: VinkiarColors.hackingGreen.withOpacity(0.4)),
                ),
                child: Text(
                  "CANAL: $provisionalGuildId\nESTADO: SINTONÍA PROVISIONAL ACTIVA",
                  style: GoogleFonts.jetBrainsMono(color: VinkiarColors.hackingGreen, fontSize: 9.5),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("MANTENER EN ESPERA", style: GoogleFonts.jetBrainsMono(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: VinkiarColors.hackingGreen,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.chat, size: 16),
              label: Text("ENTRAR AL TÚNEL", style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11)),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatQAScreen(
                      initialGuildId: provisionalGuildId,
                      initialTargetName: "TÚNEL // $targetHandle",
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ).then((_) {
        _isMatchDialogOpen = false;
      });
    });
  }

  void _openQRScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VinkiarColors.abyssBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: VinkiarColors.aegisCyan, width: 1.5),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: VinkiarColors.inkBlack,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code_scanner, color: VinkiarColors.aegisCyan, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "ESCÁNER DE GLIFOS",
                        style: GoogleFonts.jetBrainsMono(
                          color: VinkiarColors.aegisCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null) {
                          Navigator.pop(context);
                          _handleScannedGlyph(barcode.rawValue!);
                          break;
                        }
                      }
                    },
                  ),
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: VinkiarColors.aegisCyan.withOpacity(0.8),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: VinkiarColors.aegisCyan.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Center(
                      child: Text(
                        "ALINEAR GLIFO CRIPTOGRÁFICO",
                        style: GoogleFonts.jetBrainsMono(
                          color: VinkiarColors.aegisCyan,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleScannedGlyph(String code) async {
    final bool isSanctuary = code.contains("SANCTUARY") || code.contains("B2B") || code.contains("ZK-GLF");

    await VinkiarSecureDatabase().logRadarPing({
      "node_id": code,
      "alias": isSanctuary ? "La Taberna del Engranaje" : "Glifo ZKA Escaneado",
      "interaction_type": isSanctuary ? "SANCTUARY_SCAN" : "GLYPH_SCAN",
      "distance_meters": 0.0,
    });

    if (isSanctuary) {
      String cleanGlifo = code;
      if (code.contains("glifo=")) {
        cleanGlifo = Uri.tryParse(code)?.queryParameters['glifo'] ?? code;
      }
      _iniciarProcesoTokenEfimero(cleanGlifo);
      return;
    }

    if (!mounted) return;
    _mostrarDialogoGlifoEstandar();
  }

  void _iniciarProcesoTokenEfimero(String glifoId) async {
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: VinkiarColors.vertigoGold),
      ),
    );

    final tokenRes = await SantuariosService().generarTokenEfimero(
      glifoId: glifoId,
      userId: _myHandle,
    );

    if (mounted) Navigator.pop(context);

    if (tokenRes != null) {
      if (mounted) _mostrarModalTokenBarra(tokenRes);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: VinkiarColors.panicRed,
            content: Text("Error al generar firma efímera con el Santuario."),
          ),
        );
      }
    }
  }

  void _mostrarModalTokenBarra(EphemeralTokenResponse tokenData) {
    final String token = tokenData.token;
    final String promo = tokenData.promoTitulo.isNotEmpty ? tokenData.promoTitulo : "Reconexión ZKA: 2x1 en bebidas";
    final int vinks = tokenData.vinksReward;

    int secondsLeft = tokenData.ttlSeconds;
    Timer? countdownTimer;
    Timer? pollTimer;
    bool isSettled = false;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: VinkiarColors.abyssBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: VinkiarColors.vertigoGold, width: 2),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (secondsLeft > 0 && !isSettled) {
              setModalState(() => secondsLeft--);
            } else {
              t.cancel();
              pollTimer?.cancel();
            }
          });

          pollTimer ??= Timer.periodic(const Duration(seconds: 2), (t) async {
            if (isSettled || secondsLeft <= 0) {
              t.cancel();
              return;
            }
            final status = await SantuariosService().checkTokenStatus(token);
            if (status == "SETTLED") {
              t.cancel();
              countdownTimer?.cancel();
              HapticFeedback.heavyImpact();
              await VinkiarSecureDatabase().addAvatarRewards(vinks, tokenData.xpReward);
              setModalState(() => isSettled = true);
            }
          });

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isSettled ? "CANJE COMPLETADO" : "TOKEN EFÍMERO DE BARRA",
                      style: GoogleFonts.jetBrainsMono(
                        color: isSettled ? VinkiarColors.hackingGreen : VinkiarColors.vertigoGold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () {
                        countdownTimer?.cancel();
                        pollTimer?.cancel();
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isSettled) ...[
                  Text(
                    "Muestra este código al personal del Santuario para validar tu beneficio:",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: VinkiarColors.panelDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: VinkiarColors.vertigoGold, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: VinkiarColors.vertigoGold.withOpacity(0.25),
                          blurRadius: 15,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Text(
                      token,
                      style: GoogleFonts.jetBrainsMono(
                        color: VinkiarColors.vertigoGold,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_outlined, color: secondsLeft < 20 ? VinkiarColors.panicRed : VinkiarColors.aegisCyan, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "Caduca en: ${secondsLeft}s",
                        style: GoogleFonts.jetBrainsMono(
                          color: secondsLeft < 20 ? VinkiarColors.panicRed : VinkiarColors.aegisCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    promo,
                    style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 10),
                  ),
                ] else ...[
                  const Icon(Icons.verified, color: VinkiarColors.hackingGreen, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    "¡CONSUMICIÓN VALIDADA!",
                    style: GoogleFonts.jetBrainsMono(
                      color: VinkiarColors.hackingGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "+$vinks Ѵ transferidos a tu Bóveda ZKA.",
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VinkiarColors.hackingGreen,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text("CERRAR", style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _mostrarDialogoGlifoEstandar() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VinkiarColors.abyssBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: VinkiarColors.aegisCyan, width: 1.5),
        ),
        title: Text("GLIFO ZKA SINCRONIZADO", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 13, fontWeight: FontWeight.bold)),
        content: Text("ENLACE ANÓNIMO ESTABLECIDO\n+25 XP / Transmisión de Clave OK", style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("ACEPTAR", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan))),
        ],
      ),
    );
  }

  IconData _getSantuarioMapIcon(String iconoMapa, bool isFixed) {
    switch (iconoMapa.toUpperCase()) {
      case 'BAR_PUB':
        return Icons.local_bar;
      case 'CULTURA_LIBRERIA':
        return Icons.menu_book;
      case 'TERAPIA_SALUD':
        return Icons.psychology;
      case 'COWORKING':
        return Icons.laptop_mac;
      case 'OCIO_AIRE_LIBRE':
        return Icons.park;
      case 'CAFE':
      default:
        return isFixed ? Icons.local_cafe : Icons.storefront;
    }
  }

  void _showSantuarioDetail(SantuarioNode s) {
    final bool isFixed = s.tipoSantuario == "FIJO";
    final Color nodeColor = isFixed ? VinkiarColors.vertigoGold : VinkiarColors.lotusPink;
    final senuelo = s.senuelo;

    final double distMeters = Geolocator.distanceBetween(
      _userLocation.latitude, _userLocation.longitude,
      s.latitud, s.longitud,
    );
    final String distText = distMeters >= 1000
        ? "${(distMeters / 1000).toStringAsFixed(1)} km"
        : "${distMeters.toInt()}m";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: VinkiarColors.abyssBlack,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: nodeColor, width: 1.5),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        s.alias,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: nodeColor.withOpacity(0.15),
                        border: Border.all(color: nodeColor),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isFixed ? "NODO FIJO" : "NODO MÓVIL",
                        style: GoogleFonts.jetBrainsMono(color: nodeColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "SANTUARIO B2B // ${s.categoria.toUpperCase()}",
                  style: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 11),
                ),

                if (s.imagenUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      s.imagenUrl,
                      height: 115,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],

                if (s.localDireccion.isNotEmpty || s.localCiudad.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    "📍 ${[s.localDireccion, s.localCiudad].where((x) => x.isNotEmpty).join(', ')}",
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11.5),
                  ),
                ],

                if (s.medallas.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SantuarioMedallasWrap(medallas: s.medallas),
                ],

                const SizedBox(height: 8),

                if (senuelo != null && senuelo['activo'] == true) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: VinkiarColors.panelDark,
                      border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_offer, color: VinkiarColors.vertigoGold, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                senuelo['titulo'] ?? "Promoción Activa",
                                style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "Horario: ${senuelo['horario'] ?? 'Horas Valle'} | ${senuelo['multiplicador'] ?? 'x1.5 Ѵ'}",
                                style: GoogleFonts.outfit(color: VinkiarColors.vertigoGold, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                Text(
                  "DISTANCIA ESTIMADA: $distText",
                  style: GoogleFonts.jetBrainsMono(color: nodeColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text("CERRAR", style: GoogleFonts.jetBrainsMono(color: Colors.white70)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: nodeColor, foregroundColor: Colors.black),
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (s.glifosAceptados.isNotEmpty) {
                            _iniciarProcesoTokenEfimero(s.glifosAceptados.first);
                          } else {
                            _openQRScanner();
                          }
                        },
                        child: Text(
                          "CANJEAR GLIFO",
                          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 10.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNodeDetailModal(Map<String, dynamic> node) {
    if (node['isEvent'] == true && node['eventRef'] is EventoTabernaItem) {
      _showEventoDetailModal(node['eventRef'] as EventoTabernaItem);
      return;
    }
    final bool isSanctuary = node['type'] == NodeType.sanctuary;
    if (isSanctuary && node['nodeRef'] is SantuarioNode) {
      _showSantuarioDetail(node['nodeRef'] as SantuarioNode);
      return;
    }

    final Color nodeColor = node['color'] as Color;
    final senuelo = node['senuelo'] as Map<String, dynamic>?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: VinkiarColors.abyssBlack,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: nodeColor, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      node['name'],
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(node['category'], style: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 8),

              if (senuelo != null && senuelo['activo'] == true) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: VinkiarColors.panelDark,
                    border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_offer, color: VinkiarColors.vertigoGold, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              senuelo['titulo'] ?? "Promoción Activa",
                              style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Horario: ${senuelo['horario'] ?? 'Horas Valle'} | ${senuelo['multiplicador'] ?? 'x1.5 Ѵ'}",
                              style: GoogleFonts.outfit(color: VinkiarColors.vertigoGold, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              Text(
                "DISTANCIA: ${_formatDistance(node['distance'])}",
                style: GoogleFonts.jetBrainsMono(color: nodeColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text("CERRAR", style: GoogleFonts.jetBrainsMono(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: nodeColor, foregroundColor: Colors.black),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (isSanctuary) {
                          _openQRScanner();
                        } else {
                          _showHandshakeDecisionModal(
                            targetHandle: "#${node['name'].toString().replaceAll(' ', '_')}",
                            avatarAlias: node['name'],
                          );
                        }
                      },
                      child: Text(
                        isSanctuary ? "ESCANEAR GLIFO" : "PING DOBLE CIEGO (-5 ⚡)",
                        style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 10.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDistance(dynamic raw) {
    if (raw == null) return '~100m';
    final s = raw.toString();
    final clean = s.split(RegExp(r'[ (]')).first.trim();
    return clean.isNotEmpty ? clean : '~100m';
  }

  Color _getEnergyColor() {
    if (_userEnergy > 50) return VinkiarColors.hackingGreen;
    if (_userEnergy > 20) return VinkiarColors.vertigoGold;
    return VinkiarColors.panicRed;
  }

  String _getRangeLabel() {
    switch (_currentRange) {
      case RadarRange.local300m:
        return "300m";
      case RadarRange.sector1km:
        return "1 km";
      case RadarRange.sector5km:
        return "5 km";
      case RadarRange.mesh25km:
        return "25 km";
    }
  }

  Widget _buildStealthButton() {
    return InkWell(
      onTap: () {
        setState(() {
          _stealthMode = !_stealthMode;
        });
        if (!_stealthMode) {
          _startBeaconBroadcast();
        } else {
          _stopBeaconBroadcast();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: _stealthMode ? VinkiarColors.panelDark : VinkiarColors.aegisCyan.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _stealthMode ? Colors.white24 : VinkiarColors.aegisCyan),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _stealthMode ? Icons.visibility_off : Icons.wifi_tethering,
              color: _stealthMode ? Colors.grey : VinkiarColors.aegisCyan,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              _stealthMode ? "SIGILO" : "VISIBLE",
              style: GoogleFonts.jetBrainsMono(
                color: _stealthMode ? Colors.grey : VinkiarColors.aegisCyan,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeButton() {
    return InkWell(
      onTap: _cycleRange,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: VinkiarColors.panelDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_outlined, color: VinkiarColors.vertigoGold, size: 14),
            const SizedBox(width: 4),
            Text(
              "RANGO: ${_getRangeLabel()}",
              style: GoogleFonts.jetBrainsMono(
                color: VinkiarColors.vertigoGold,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyWidget(Color energyColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: VinkiarColors.panelDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: energyColor.withOpacity(0.6), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, color: energyColor, size: 14),
          const SizedBox(width: 4),
          Text(
            "$_userEnergy ⚡",
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isWsConnected ? VinkiarColors.hackingGreen : VinkiarColors.panicRed,
            ),
          ),
          if (_isLoadingGps) ...[
            const SizedBox(width: 6),
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: VinkiarColors.aegisCyan),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFloatingDock() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: VinkiarColors.abyssBlack.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.4), width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _viewMode == RadarViewMode.vectorRadar ? Icons.map_outlined : Icons.radar,
              color: _viewMode == RadarViewMode.vectorRadar ? neonGreen : VinkiarColors.vertigoGold,
              size: 20,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() {
                _viewMode = _viewMode == RadarViewMode.vectorRadar
                    ? RadarViewMode.darkMap
                    : RadarViewMode.vectorRadar;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: VinkiarColors.aegisCyan, size: 20),
            onPressed: () {
              HapticFeedback.selectionClick();
              _openQRScanner();
            },
          ),
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white70, size: 20),
            onPressed: () {
              HapticFeedback.selectionClick();
              _fetchRealGpsLocation();
            },
          ),
          IconButton(
            icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen, color: VinkiarColors.aegisCyan, size: 20),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _isFullScreen = !_isFullScreen);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final energyColor = _getEnergyColor();
    final mediaQuery = MediaQuery.of(context);
    final bool isKeyboardOpen = mediaQuery.viewInsets.bottom > 0;
    final bool isCompactHeight = mediaQuery.size.height < 460 || isKeyboardOpen;

    return Scaffold(
      backgroundColor: VinkiarColors.abyssBlack,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                if (!_isFullScreen)
                  Container(
                    color: VinkiarColors.inkBlack,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStealthButton(),
                        _buildRangeButton(),
                        InkWell(
                          onTap: _toggleSantuarioAlertRadius,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                            decoration: BoxDecoration(
                              color: VinkiarColors.panelDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: VinkiarColors.hackingGreen.withOpacity(0.55)),
                            ),
                            child: Text(
                              "🔔 ${_santuarioAlertRadiusMeters.toInt()}m",
                              style: GoogleFonts.jetBrainsMono(
                                color: VinkiarColors.hackingGreen,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        _buildEnergyWidget(energyColor),
                      ],
                    ),
                  ),

                if (!_isFullScreen)
                  Container(
                    color: VinkiarColors.panelDark,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: VinkiarColors.abyssBlack,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tag, color: VinkiarColors.aegisCyan, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _handleSearchController,
                              style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11),
                              decoration: const InputDecoration(
                                hintText: "Buscar por #NombreAvatar",
                                hintStyle: TextStyle(color: Colors.white38, fontSize: 10.5),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: (_) => _searchAvatarByHandle(),
                            ),
                          ),
                          IconButton(
                            icon: _isSearchingHandle
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: VinkiarColors.aegisCyan),
                                  )
                                : const Icon(Icons.search, color: VinkiarColors.aegisCyan, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _isSearchingHandle ? null : _searchAvatarByHandle,
                          ),
                        ],
                      ),
                    ),
                  ),

                if (!_isFullScreen && _incomingPings.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF17130A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: VinkiarColors.vertigoGold, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: VinkiarColors.vertigoGold.withOpacity(0.22),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.sensors, color: VinkiarColors.vertigoGold, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "PING DOBLE CIEGO ENTRANTE (${_incomingPings.length})",
                                  style: GoogleFonts.jetBrainsMono(
                                    color: VinkiarColors.vertigoGold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () => setState(() => _incomingPings.removeAt(0)),
                              child: const Icon(Icons.close, color: Colors.white54, size: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${_incomingPings.first['sender_handle']} (${_incomingPings.first['archetype'] ?? 'AVATAR ZKA'}) solicita sintonía.",
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VinkiarColors.hackingGreen,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                            ),
                            icon: const Icon(Icons.handshake, size: 16),
                            label: Text(
                              "RESPONDER SINTONÍA (-$_pingEnergyCost ⚡)",
                              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                            onPressed: () {
                              final ping = _incomingPings.removeAt(0);
                              setState(() {});
                              final senderH = ping['sender_handle']?.toString() ?? '#Avatar';
                              _showHandshakeDecisionModal(
                                targetHandle: senderH,
                                avatarAlias: senderH,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                if (!_isFullScreen && _searchHandleError != null)
                  Container(
                    width: double.infinity,
                    color: VinkiarColors.panicRed.withOpacity(0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: VinkiarColors.panicRed, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _searchHandleError!,
                            style: GoogleFonts.jetBrainsMono(color: VinkiarColors.panicRed, fontSize: 10),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _searchHandleError = null),
                        ),
                      ],
                    ),
                  ),

                if (!_isFullScreen && _searchedAvatar != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: VinkiarColors.panelDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: VinkiarColors.aegisCyan, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: VinkiarColors.aegisCyan.withOpacity(0.2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_search, color: VinkiarColors.aegisCyan, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _searchedAvatar!['handle'] ?? '#Avatar',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _searchedAvatar = null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${_searchedAvatar!['character_class'] ?? 'AVATAR ZKA'} · Vector [${_searchedAvatar!['public_vector'] ?? '5-8-2'}] · Rep: ${((_searchedAvatar!['reputation_score'] ?? 0.95) * 100).toInt()}%",
                          style: GoogleFonts.jetBrainsMono(color: Colors.white60, fontSize: 9.5),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VinkiarColors.aegisCyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.sensors, size: 16),
                            label: Text(
                              "PING DOBLE CIEGO (-$_pingEnergyCost ⚡)",
                              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 10.5),
                            ),
                            onPressed: () {
                              final handle = _searchedAvatar!['handle']?.toString() ?? '#kaelen_void';
                              setState(() => _searchedAvatar = null);
                              _showHandshakeDecisionModal(
                                targetHandle: handle,
                                avatarAlias: handle,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: _viewMode == RadarViewMode.vectorRadar
                      ? _buildVectorRadarCanvas()
                      : _buildRealDarkMap(),
                ),

                if (_detectedNodes.isNotEmpty && !_isScanning && _showNodesList && !_isFullScreen && !isCompactHeight)
                  Container(
                    height: 90,
                    color: VinkiarColors.inkBlack,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _detectedNodes.length,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemBuilder: (context, index) {
                        final node = _detectedNodes[index];
                        final bool isSanctuary = node['type'] == NodeType.sanctuary;
                        final Color nodeColor = node['color'] as Color;

                        return GestureDetector(
                          onTap: () => _showNodeDetailModal(node),
                          child: Container(
                            width: 180,
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: VinkiarColors.abyssBlack,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: nodeColor.withOpacity(0.5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        isSanctuary ? "🏛️ SANTUARIO" : "👤 AVATAR",
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.jetBrainsMono(
                                          color: nodeColor,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatDistance(node['distance']),
                                      style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 8.5),
                                    ),
                                  ],
                                ),
                                Text(
                                  node['name'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  node['reward'] ?? '+50 Ѵ | +20 XP',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.jetBrainsMono(color: isSanctuary ? VinkiarColors.vertigoGold : neonGreen, fontSize: 8),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                if (!_isFullScreen && !isCompactHeight)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: InkWell(
                      onTap: _triggerScan,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _isScanning ? VinkiarColors.inkBlack : VinkiarColors.abyssBlack,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _userEnergy >= _scanEnergyCost ? neonGreen : VinkiarColors.panicRed, width: 1.2),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.radar,
                                color: _userEnergy >= _scanEnergyCost ? neonGreen : VinkiarColors.panicRed,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isScanning
                                    ? "BARRIDO EN CURSO..."
                                    : "BARRIDO DE ENTORNO (${_getRangeLabel()} | -$_scanEnergyCost ⚡)",
                                style: GoogleFonts.jetBrainsMono(
                                  color: _userEnergy >= _scanEnergyCost ? neonGreen : VinkiarColors.panicRed,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            if (!isKeyboardOpen)
              Positioned(
                top: _isFullScreen ? 20 : 120,
                right: 12,
                child: _buildFloatingDock(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVectorRadarCanvas() {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double canvasSize = min(constraints.maxWidth, constraints.maxHeight);
          if (canvasSize <= 0) return const SizedBox.shrink();

          return SizedBox(
            width: canvasSize,
            height: canvasSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(canvasSize, canvasSize),
                      painter: RadarPainter(
                        pulseVal: _pulseController.value,
                        isScanning: _isScanning,
                        nodes: _detectedNodes,
                        rangeLabel: _getRangeLabel(),
                      ),
                    );
                  },
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: VinkiarColors.aegisCyan,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: VinkiarColors.aegisCyan.withOpacity(0.8), blurRadius: 10, spreadRadius: 2)
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRealDarkMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _userLocation,
        initialZoom: _currentRange == RadarRange.local300m ? 16.8 : (_currentRange == RadarRange.sector1km ? 15.2 : (_currentRange == RadarRange.sector5km ? 13.5 : 11.0)),
        minZoom: 9.0,
        maxZoom: 19.0,
      ),
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            -0.85, 0.0, 0.0, 0.0, 255.0,
            0.0, -0.85, 0.0, 0.0, 255.0,
            0.0, 0.0, -0.75, 0.0, 255.0,
            0.0, 0.0, 0.0, 1.0, 0.0,
          ]),
          child: TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.vinkiar.sor.vinkiar_flutter',
            maxZoom: 19,
          ),
        ),
        CircleLayer(
          circles: [
            // Radio de aviso de Santuarios cercanos (500m o 1000m)
            CircleMarker(
              point: _userLocation,
              radius: _santuarioAlertRadiusMeters,
              useRadiusInMeter: true,
              color: VinkiarColors.vertigoGold.withOpacity(0.04),
              borderColor: VinkiarColors.vertigoGold.withOpacity(0.28),
              borderStrokeWidth: 1.0,
            ),
            // Radio de detección cercana de Avatares (300m)
            CircleMarker(
              point: _userLocation,
              radius: _avatarProximityAlertMeters,
              useRadiusInMeter: true,
              color: VinkiarColors.aegisCyan.withOpacity(0.06),
              borderColor: VinkiarColors.aegisCyan.withOpacity(0.35),
              borderStrokeWidth: 1.0,
            ),
            // Anillos de Jitter (300m) alrededor de Santuarios Móviles
            ..._santuarios.where((s) => s.tipoSantuario == "MOVIL").map(
                  (s) => CircleMarker(
                    point: LatLng(s.latitud, s.longitud),
                    radius: 300.0,
                    useRadiusInMeter: true,
                    color: VinkiarColors.lotusPink.withOpacity(0.10),
                    borderColor: VinkiarColors.lotusPink.withOpacity(0.55),
                    borderStrokeWidth: 1.2,
                  ),
                ),
          ],
        ),
        MarkerLayer(
          markers: [
            // Marcador de Posición del Usuario
            Marker(
              point: _userLocation,
              width: 50,
              height: 50,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: VinkiarColors.aegisCyan,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: VinkiarColors.aegisCyan.withOpacity(0.9),
                          blurRadius: 10,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Marcadores de Balizas de Santuarios B2B con icono dinámico
            ..._santuarios.map((s) {
              final bool isFixed = s.tipoSantuario == "FIJO";
              return Marker(
                point: LatLng(s.latitud, s.longitud),
                width: 36,
                height: 36,
                child: GestureDetector(
                  onTap: () => _showSantuarioDetail(s),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isFixed ? const Color(0xFF10121A) : const Color(0xFF1A1210),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isFixed ? VinkiarColors.vertigoGold : VinkiarColors.lotusPink,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isFixed ? VinkiarColors.vertigoGold : VinkiarColors.lotusPink).withOpacity(0.4),
                          blurRadius: 8,
                        )
                      ],
                    ),
                    child: Icon(
                      _getSantuarioMapIcon(s.iconoMapa, isFixed),
                      color: isFixed ? VinkiarColors.vertigoGold : VinkiarColors.lotusPink,
                      size: 18,
                    ),
                  ),
                ),
              );
            }).toList(),
            // Marcadores de Eventos de La Taberna
            ..._eventosTaberna.map((ev) {
              return Marker(
                point: LatLng(ev.latitud, ev.longitud),
                width: 38,
                height: 38,
                child: GestureDetector(
                  onTap: () => _showEventoDetailModal(ev),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1610),
                      shape: BoxShape.circle,
                      border: Border.all(color: VinkiarColors.hackingGreen, width: 1.8),
                      boxShadow: [
                        BoxShadow(
                          color: VinkiarColors.hackingGreen.withOpacity(0.45),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.event_available,
                      color: VinkiarColors.hackingGreen,
                      size: 18,
                    ),
                  ),
                ),
              );
            }).toList(),
            // Marcadores de Avatares (P2P Mesh)
            ..._detectedNodes.where((n) => n['type'] == NodeType.avatar).map((node) {
              final LatLng pos = node['location'] as LatLng;
              final Color color = node['color'] as Color;

              return Marker(
                point: pos,
                width: 44,
                height: 44,
                child: GestureDetector(
                  onTap: () => _showNodeDetailModal(node),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: VinkiarColors.abyssBlack,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person_pin,
                      color: color,
                      size: 20,
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ],
    );
  }
}

class RadarPainter extends CustomPainter {
  final double pulseVal;
  final bool isScanning;
  final List<JsonMap> nodes;
  final String rangeLabel;

  RadarPainter({
    required this.pulseVal,
    required this.isScanning,
    required this.nodes,
    required this.rangeLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2 * 0.9;

    final paintGrid = Paint()
      ..color = const Color(0xFF39FF14).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * (i / 4.0), paintGrid);
    }
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), paintGrid);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), paintGrid);

    final pulseRadius = maxRadius * pulseVal;
    final paintPulse = Paint()
      ..color = const Color(0xFF39FF14).withOpacity(0.4 * (1.0 - pulseVal))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, pulseRadius, paintPulse);

    if (isScanning) {
      final sweepAngle = pulseVal * 2 * pi;
      final sweepEnd = Offset(center.dx + maxRadius * cos(sweepAngle), center.dy + maxRadius * sin(sweepAngle));
      final paintSweep = Paint()
        ..color = const Color(0xFF39FF14).withOpacity(0.6)
        ..strokeWidth = 2.0;
      canvas.drawLine(center, sweepEnd, paintSweep);
    }

    if (!isScanning) {
      for (var node in nodes) {
        final double angle = node['angle'] as double;
        final double r = (node['radius'] as double) * maxRadius;
        final Offset nodePos = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
        final Color nodeColor = node['color'] as Color;

        canvas.drawCircle(nodePos, 6.0, Paint()..color = nodeColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.pulseVal != pulseVal || oldDelegate.isScanning != isScanning || oldDelegate.nodes != nodes || oldDelegate.rangeLabel != rangeLabel;
  }
}