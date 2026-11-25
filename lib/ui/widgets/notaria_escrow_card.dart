import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/notaria_escrow_service.dart';
import '../theme.dart';

typedef JsonMap = Map<String, dynamic>;

class NotariaEscrowCard extends StatefulWidget {
  final String questId;
  final String santuarioId;
  final String santuarioAlias;
  final String horaPactada;
  final int escrowVinks;
  final String myHandle;
  final String targetHandle;
  final bool isP2PTask;

  const NotariaEscrowCard({
    Key? key,
    required this.questId,
    required this.santuarioId,
    required this.santuarioAlias,
    required this.horaPactada,
    required this.escrowVinks,
    required this.myHandle,
    required this.targetHandle,
    this.isP2PTask = false,
  }) : super(key: key);

  @override
  State<NotariaEscrowCard> createState() => _NotariaEscrowCardState();
}

class _NotariaEscrowCardState extends State<NotariaEscrowCard> {
  final TextEditingController _chatInputController = TextEditingController();

  String _contractStatus = 'FROZEN'; // FROZEN | WAITING_PEER | SETTLED
  String _santuarioStatus = 'SCHEDULED'; // SCHEDULED | CONFIRMED | RESCHEDULED
  String _horaActual = '';
  String _telefonoLocal = '+34 954 12 88 90';
  String _contactoLocal = '@engranaje_sevilla';
  String? _encuentroId;

  List<JsonMap> _mensajesLocal = [];
  bool _showMinichat = false;
  bool _isSendingMsg = false;
  bool _isConfirmingHour = false;
  bool _isSigning = false;
  Timer? _pollTimer;

  String get _cleanBaseUrl {
    return ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
  }

  @override
  void initState() {
    super.initState();
    _horaActual = widget.horaPactada;
    _initStateSync();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _chatInputController.dispose();
    super.dispose();
  }

  Future<void> _initStateSync() async {
    final local = await NotariaEscrowService().getLocalEscrow(widget.questId);
    if (local != null && mounted) {
      setState(() {
        if (local['status'] == 'SETTLED') {
          _contractStatus = 'SETTLED';
        } else if (local['my_signed'] == true) {
          _contractStatus = 'WAITING_PEER';
        }
      });
    }
    _checkRemoteUpdates();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_contractStatus != 'SETTLED') {
        _checkRemoteUpdates();
      }
    });
  }

  Future<void> _checkRemoteUpdates() async {
    final sigRes = await NotariaEscrowService().pollContractStatus(widget.questId);
    if (sigRes['status'] == 'MUTUAL_SETTLED' && mounted) {
      setState(() => _contractStatus = 'SETTLED');
    }

    if (widget.isP2PTask) return;

    try {
      final res = await http.get(
        Uri.parse('$_cleanBaseUrl/api/v1/santuarios/encuentros/${widget.santuarioId}'),
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as JsonMap;
        final encuentros = data['encuentros'] as List? ?? [];
        if (encuentros.isNotEmpty) {
          final targetClean = widget.targetHandle.replaceAll('#', '').toLowerCase();
          final matched = encuentros.cast<JsonMap>().firstWhere(
                (e) => (e['user_b_handle'] ?? '').toString().toLowerCase().contains(targetClean),
                orElse: () => encuentros.first as JsonMap,
              );

          final rawMsgs = matched['mensajes'] as List? ?? [];
          final parsedMsgs = rawMsgs.map((m) => Map<String, dynamic>.from(m as Map)).toList();

          setState(() {
            _encuentroId = matched['encuentro_id']?.toString();
            _santuarioStatus = matched['status']?.toString() ?? 'SCHEDULED';
            if (matched['fecha_estimada'] != null) {
              _horaActual = matched['fecha_estimada'].toString();
            }
            if (matched['telefono'] != null) {
              _telefonoLocal = matched['telefono'].toString();
            }
            if (matched['contacto'] != null) {
              _contactoLocal = matched['contacto'].toString();
            }
            _mensajesLocal = parsedMsgs;
            if (_santuarioStatus == 'RESCHEDULED') {
              _showMinichat = true;
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _confirmarNuevaHora() async {
    if (_encuentroId == null || _isConfirmingHour) return;
    setState(() => _isConfirmingHour = true);
    HapticFeedback.mediumImpact();

    try {
      final res = await http.put(
        Uri.parse('$_cleanBaseUrl/api/v1/santuarios/encuentros/$_encuentroId/confirmar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'santuario_id': widget.santuarioId,
          'accion': 'CONFIRMED',
          'nueva_hora': _horaActual,
          'nota_local': 'Nueva hora aceptada por el asistente',
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 && mounted) {
        setState(() => _santuarioStatus = 'CONFIRMED');
        await _checkRemoteUpdates();
      }
    } catch (_) {}

    if (mounted) setState(() => _isConfirmingHour = false);
  }

  Future<void> _enviarMensajeAlLocal() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty || _encuentroId == null || _isSendingMsg) return;

    setState(() => _isSendingMsg = true);
    _chatInputController.clear();

    try {
      final res = await http.post(
        Uri.parse('$_cleanBaseUrl/api/v1/santuarios/encuentros/$_encuentroId/mensaje'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'santuario_id': widget.santuarioId,
          'sender': widget.myHandle,
          'text': text,
          'is_santuario': false,
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 201 || res.statusCode == 200) {
        await _checkRemoteUpdates();
      }
    } catch (_) {}

    if (mounted) setState(() => _isSendingMsg = false);
  }

  Future<void> _emitirFirmaNotarial() async {
    if (_isSigning) return;
    setState(() => _isSigning = true);
    HapticFeedback.mediumImpact();

    final res = await NotariaEscrowService().signContract2of2(
      questId: widget.questId,
      signerHandle: widget.myHandle,
      targetHandle: widget.targetHandle,
      role: 'CREATOR',
    );

    if (!mounted) return;
    setState(() {
      _isSigning = false;
      if (res['status'] == 'MUTUAL_SETTLED') {
        _contractStatus = 'SETTLED';
        HapticFeedback.heavyImpact();
      } else if (res['status'] == 'SIGNATURE_REGISTERED') {
        _contractStatus = 'WAITING_PEER';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isSettled = _contractStatus == 'SETTLED';
    final bool isRescheduled = !widget.isP2PTask && _santuarioStatus == 'RESCHEDULED';
    final Color borderColor = isSettled
        ? VinkiarColors.hackingGreen
        : (widget.isP2PTask ? VinkiarColors.aegisCyan : VinkiarColors.vertigoGold);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10121A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.18),
            blurRadius: 12,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CABECERA NOTARIAL
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isSettled ? Icons.verified : Icons.gavel_outlined,
                    color: borderColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isSettled
                        ? "CONTRATO LIQUIDADO (2-DE-2)"
                        : (widget.isP2PTask ? "SUBASTA P2P // ESCROW" : "NOTARÍA ZKA // ESCROW"),
                    style: GoogleFonts.jetBrainsMono(
                      color: borderColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: borderColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "${widget.escrowVinks} Ѵ",
                  style: GoogleFonts.jetBrainsMono(
                    color: borderColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 14),

          // TÍTULO DE LA TAREA O SANTUARIO
          Text(
            widget.isP2PTask ? "📜 ${widget.santuarioAlias}" : "🏛️ ${widget.santuarioAlias}",
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),

          if (widget.isP2PTask) ...[
            if (_horaActual.isNotEmpty)
              Text(
                _horaActual,
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11.5),
              ),
            const SizedBox(height: 4),
            Text(
              "Asignado a: ${widget.targetHandle}",
              style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 9.5),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "🕒 $_horaActual",
                  style: GoogleFonts.jetBrainsMono(
                    color: isRescheduled ? VinkiarColors.vertigoGold : VinkiarColors.aegisCyan,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _santuarioStatus == "CONFIRMED"
                      ? "✅ LOCAL CONFIRMADO"
                      : isRescheduled
                          ? "⚠️ CAMBIO PROPUESTO"
                          : "⏳ AVISO ENVIADO",
                  style: GoogleFonts.jetBrainsMono(
                    color: _santuarioStatus == "CONFIRMED"
                        ? VinkiarColors.hackingGreen
                        : isRescheduled
                            ? VinkiarColors.vertigoGold
                            : Colors.white54,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // BARRA DE COMUNICACIÓN DIRECTA CON EL LOCAL (SOLO SANTUARIOS)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF08090C),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _telefonoLocal));
                      HapticFeedback.selectionClick();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: VinkiarColors.aegisCyan,
                          duration: const Duration(seconds: 2),
                          content: Text(
                            "📞 Teléfono $_telefonoLocal copiado al portapapeles",
                            style: GoogleFonts.jetBrainsMono(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.phone_in_talk, color: VinkiarColors.hackingGreen, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _telefonoLocal,
                          style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 10),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy, color: Colors.white38, size: 11),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _showMinichat = !_showMinichat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: VinkiarColors.aegisCyan.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline, color: VinkiarColors.aegisCyan, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            "LOCAL (${_mensajesLocal.length})",
                            style: GoogleFonts.jetBrainsMono(
                              color: VinkiarColors.aegisCyan,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (isRescheduled) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VinkiarColors.vertigoGold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: VinkiarColors.vertigoGold),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "El Santuario propone ajustar la hora a: $_horaActual",
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VinkiarColors.hackingGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 15),
                        label: Text(
                          _isConfirmingHour ? "CONFIRMANDO..." : "ACEPTAR Y CONFIRMAR NUEVA HORA",
                          style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isConfirmingHour ? null : _confirmarNuevaHora,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_showMinichat) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF08090C),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "CANAL DIRECTO // $_contactoLocal",
                      style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    if (_mensajesLocal.isEmpty)
                      Text(
                        "Escribe aquí para consultar disponibilidad o avisar si llegas unos minutos tarde.",
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10),
                      )
                    else
                      Column(
                        children: _mensajesLocal.map((m) {
                          final bool fromLocal = m['is_santuario'] == true;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fromLocal ? "🏛️ Local: " : "👤 Tú: ",
                                  style: GoogleFonts.jetBrainsMono(
                                    color: fromLocal ? VinkiarColors.vertigoGold : VinkiarColors.aegisCyan,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    m['text']?.toString() ?? '',
                                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 10.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatInputController,
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 11),
                            decoration: InputDecoration(
                              hintText: "Mensaje al local...",
                              hintStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 10.5),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                              filled: true,
                              fillColor: const Color(0xFF10121A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _enviarMensajeAlLocal(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: _enviarMensajeAlLocal,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: VinkiarColors.aegisCyan,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.send, color: Colors.black, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 12),

          // ACCIÓN NOTARIAL 2-DE-2
          if (isSettled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VinkiarColors.hackingGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: VinkiarColors.hackingGreen.withOpacity(0.4)),
              ),
              child: Text(
                widget.isP2PTask
                    ? "✨ Tarea certificada (2-de-2). ${widget.escrowVinks} Ѵ liberados a ${widget.targetHandle} (+100 XP acreditados)."
                    : "✨ Doble firma completada. Depósito liberado (+${widget.escrowVinks + 25} Ѵ y +150 XP acreditados en Bóveda).",
                style: GoogleFonts.outfit(color: VinkiarColors.hackingGreen, fontSize: 11),
              ),
            )
          else if (_contractStatus == 'WAITING_PEER')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VinkiarColors.aegisCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "🔏 Tu firma criptográfica está registrada. Esperando contra-firma de ${widget.targetHandle}...",
                style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 9.5),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: borderColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: _isSigning
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.fingerprint, size: 18),
                label: Text(
                  _isSigning
                      ? "SELLANDO FIRMA SHA-256..."
                      : (widget.isP2PTask ? "CERTIFICAR TAREA COMPLETADA (2-DE-2)" : "FIRMAR ENCUENTRO COMPLETADO (2-DE-2)"),
                  style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 10),
                ),
                onPressed: _isSigning ? null : _emitirFirmaNotarial,
              ),
            ),
        ],
      ),
    );
  }
}