import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/onboarding_guide_service.dart';
import '../../services/vinkiar_tribus_service.dart';
import '../theme.dart';

class TribuBolsaComunSheet extends StatefulWidget {
  final String guildId;
  final String guildName;
  final String myHandle;
  final bool isCreator;
  final void Function(String note)? onBroadcastChatNote;

  const TribuBolsaComunSheet({
    Key? key,
    required this.guildId,
    this.guildName = 'Tribu ZKA',
    this.myHandle = '#Pionero',
    this.isCreator = false,
    this.onBroadcastChatNote,
  }) : super(key: key);

  @override
  State<TribuBolsaComunSheet> createState() => _TribuBolsaComunSheetState();
}

class _TribuBolsaComunSheetState extends State<TribuBolsaComunSheet> {
  final _tribusService = VinkiarTribusService();
  bool _isLoading = true;
  int _myLocalVinks = 150;
  Map<String, dynamic>? _tribuData;

  @override
  void initState() {
    super.initState();
    _fetchBolsa();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        OnboardingGuideService().showIfFirstTime(context, OnboardingTopic.tribuBolsaComun);
      }
    });
  }

  Future<void> _fetchBolsa() async {
    setState(() => _isLoading = true);
    final localVinks = await _tribusService.getLocalVinksBalance();
    final data = await _tribusService.fetchTribuBolsa(
      widget.guildId,
      guildName: widget.guildName,
      memberHandle: widget.myHandle,
    );
    if (mounted) {
      setState(() {
        _myLocalVinks = localVinks;
        _tribuData = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _aportarFondo() async {
    HapticFeedback.lightImpact();
    final ctrl = TextEditingController();
    final conceptCtrl = TextEditingController(text: "Aportación al fondo de contingencia");

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VinkiarColors.abyssBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: VinkiarColors.vertigoGold, width: 1.5),
        ),
        title: Text(
          "APORTAR A BOLSA COMÚN",
          style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tu saldo personal disponible: $_myLocalVinks Ѵ",
              style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 10.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: conceptCtrl,
              style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(labelText: "Concepto", labelStyle: TextStyle(color: Colors.white60, fontSize: 11)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 16),
              decoration: const InputDecoration(labelText: "Cantidad (Vinks Ѵ)", labelStyle: TextStyle(color: Colors.white60, fontSize: 11)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCELAR", style: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 11)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: VinkiarColors.vertigoGold, foregroundColor: Colors.black),
            onPressed: () async {
              final amount = int.tryParse(ctrl.text.trim()) ?? 0;
              if (amount > 0) {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                final res = await _tribusService.aportarVinks(
                  widget.guildId,
                  amount,
                  conceptCtrl.text.trim(),
                  memberHandle: widget.myHandle,
                );
                if (!mounted) return;
                if (res != null && res['error'] == null) {
                  final newLocal = (res['_local_vinks_after'] as num?)?.toInt() ?? await _tribusService.getLocalVinksBalance();
                  if (!mounted) return;
                  setState(() {
                    _myLocalVinks = newLocal;
                    _tribuData = res;
                    _isLoading = false;
                  });
                  HapticFeedback.heavyImpact();
                  widget.onBroadcastChatNote?.call(
                    "💰 [BOLSA COMÚN]: ${widget.myHandle} aportó +$amount Ѵ (${conceptCtrl.text.trim()}).",
                  );
                } else {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res?['error']?.toString() ?? 'Error de saldo'),
                      backgroundColor: VinkiarColors.panicRed,
                    ),
                  );
                }
              }
            },
            child: Text("APORTAR", style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _proponerGasto() async {
    HapticFeedback.lightImpact();
    final amountCtrl = TextEditingController();
    final conceptCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VinkiarColors.abyssBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: VinkiarColors.aegisCyan, width: 1.5),
        ),
        title: Text(
          "PROPONER GASTO DE TRIBU",
          style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: conceptCtrl,
              style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                labelText: "Destino / Actividad",
                labelStyle: TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 16),
              decoration: const InputDecoration(
                labelText: "Importe (Vinks Ѵ)",
                labelStyle: TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCELAR", style: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 11)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: VinkiarColors.aegisCyan, foregroundColor: Colors.black),
            onPressed: () async {
              final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
              final concept = conceptCtrl.text.trim();
              if (amount > 0 && concept.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                final res = await _tribusService.proponerGasto(
                  guildId: widget.guildId,
                  amount: amount,
                  concepto: concept,
                  proposerHandle: widget.myHandle,
                );
                if (!mounted) return;
                if (res != null && res['error'] == null) {
                  final newLocal = (res['_local_vinks_after'] as num?)?.toInt() ?? await _tribusService.getLocalVinksBalance();
                  if (!mounted) return;
                  setState(() {
                    _myLocalVinks = newLocal;
                    _tribuData = res;
                    _isLoading = false;
                  });
                  widget.onBroadcastChatNote?.call(
                    "📜 [PROPUESTA BOLSA]: ${widget.myHandle} propuso destinar $amount Ѵ a '$concept'.",
                  );
                } else {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res?['error']?.toString() ?? 'No se pudo crear propuesta'),
                      backgroundColor: VinkiarColors.panicRed,
                    ),
                  );
                }
              }
            },
            child: Text("PROPONER", style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 300,
        decoration: const BoxDecoration(
          color: VinkiarColors.abyssBlack,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(child: CircularProgressIndicator(color: VinkiarColors.vertigoGold)),
      );
    }

    if (_tribuData == null) {
      return Container(
        height: 260,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: VinkiarColors.abyssBlack,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: VinkiarColors.panicRed, size: 40),
            const SizedBox(height: 16),
            Text(
              "NO SE PUDO CONECTAR CON LA TESORERÍA",
              style: GoogleFonts.jetBrainsMono(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: VinkiarColors.panelDark),
              onPressed: _fetchBolsa,
              child: const Text("REINTENTAR"),
            )
          ],
        ),
      );
    }

    final int saldo = _tribuData!['saldo_vinks'] ?? 0;
    final int reqApprovals = _tribuData!['required_approvals'] ?? 1;
    final String mode = _tribuData!['decision_mode'] ?? 'QUORUM';
    final List<dynamic> movimientos = _tribuData!['movimientos'] ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
      decoration: const BoxDecoration(
        color: VinkiarColors.abyssBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: VinkiarColors.vertigoGold, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "BOLSA COMÚN // ${widget.guildName.toUpperCase()}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Tu saldo Bóveda: $_myLocalVinks Ѵ · ${widget.myHandle}",
                      style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: VinkiarColors.panelDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.4)),
            ),
            child: Column(
              children: [
                Text(
                  "SALDO DISPONIBLE EN TESORERÍA",
                  style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  "$saldo Ѵ",
                  style: GoogleFonts.jetBrainsMono(
                    color: VinkiarColors.vertigoGold,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: VinkiarColors.vertigoGold.withOpacity(0.5), blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMetaBadge("MODO: $mode"),
                    _buildMetaBadge("QUÓRUM: $reqApprovals votos"),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VinkiarColors.vertigoGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        icon: const Icon(Icons.add_circle, size: 16),
                        label: Text("APORTAR", style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        onPressed: _aportarFondo,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: VinkiarColors.aegisCyan,
                          side: const BorderSide(color: VinkiarColors.aegisCyan),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        icon: const Icon(Icons.outbox, size: 16),
                        label: Text("PROPONER GASTO", style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold)),
                        onPressed: _proponerGasto,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "REGISTRO DE MOVIMIENTOS Y PROPUESTAS",
            style: GoogleFonts.jetBrainsMono(color: VinkiarColors.textHdr, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: movimientos.isEmpty
                ? Center(child: Text("La Bolsa Común está en silencio.", style: GoogleFonts.outfit(color: VinkiarColors.textDim)))
                : ListView.builder(
                    itemCount: movimientos.length,
                    itemBuilder: (ctx, i) {
                      final m = movimientos[i];
                      final isIngreso = m['tipo'] == 'APORTACION';
                      final isPending = m['status'] == 'PENDING';
                      final color = isIngreso
                          ? VinkiarColors.hackingGreen
                          : (isPending ? VinkiarColors.vertigoGold : VinkiarColors.aegisCyan);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VinkiarColors.inkBlack,
                          borderRadius: BorderRadius.circular(10),
                          border: Border(left: BorderSide(color: color, width: 3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(isIngreso ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 16),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m['concepto'] ?? 'Movimiento',
                                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        "${m['proposer_handle']} · ${m['status']} (${m['approvals_count'] ?? 0}/${m['required_approvals'] ?? 1})",
                                        style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 9),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  "${isIngreso ? '+' : '-'}${m['monto_vinks']} Ѵ",
                                  style: GoogleFonts.jetBrainsMono(color: color, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (isPending) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () async {
                                      final updated = await _tribusService.votarGasto(
                                        guildId: widget.guildId,
                                        movimientoId: m['id'].toString(),
                                        decision: 'VETO_ROJO',
                                        voterHandle: widget.myHandle,
                                      );
                                      if (updated != null && mounted) setState(() => _tribuData = updated);
                                    },
                                    child: Text("VETO SSC", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.panicRed, fontSize: 9.5)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: VinkiarColors.hackingGreen,
                                      foregroundColor: Colors.black,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () async {
                                      final updated = await _tribusService.votarGasto(
                                        guildId: widget.guildId,
                                        movimientoId: m['id'].toString(),
                                        decision: 'APPROVE',
                                        voterHandle: widget.myHandle,
                                      );
                                      if (updated != null && mounted) setState(() => _tribuData = updated);
                                    },
                                    child: Text("APROBAR", style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: VinkiarColors.inkBlack,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(text, style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}
