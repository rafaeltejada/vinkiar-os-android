import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/vinkiar_tribus_service.dart';
import '../theme.dart';

class DecisionPollCard extends StatefulWidget {
  final String decisionId;
  final String fallbackTitle;
  final String fallbackMode;
  final String myHandle;
  final void Function(String note)? onResolvedBroadcast;
  final VoidCallback? onDecisionUpdated;
  final Map<String, dynamic>? initialDecisionData;

  const DecisionPollCard({
    Key? key,
    required this.decisionId,
    this.fallbackTitle = 'Decisión Colectiva ZKA',
    this.fallbackMode = 'QUORUM',
    this.myHandle = '#Pionero',
    this.onResolvedBroadcast,
    this.onDecisionUpdated,
    this.initialDecisionData,
  }) : super(key: key);

  @override
  State<DecisionPollCard> createState() => _DecisionPollCardState();
}

class _DecisionPollCardState extends State<DecisionPollCard> {
  final _tribusService = VinkiarTribusService();
  bool _isLoading = true;
  bool _isProcessing = false;
  Map<String, dynamic>? _decisionData;
  final Map<String, double> _comfortScores = {};
  final Set<String> _vetoedIds = {};
  final TextEditingController _bidController = TextEditingController(text: '25');
  String? _selectedBidOptionId;

  @override
  void initState() {
    super.initState();
    _decisionData = widget.initialDecisionData;
    _loadDecision();
  }

  @override
  void dispose() {
    _bidController.dispose();
    super.dispose();
  }

  Future<void> _loadDecision() async {
    final fresh = await _tribusService.fetchDecisionDetail(widget.decisionId);
    if (!mounted) return;
    setState(() {
      if (fresh != null) {
        _decisionData = fresh;
        final ops = (fresh['opciones'] as List<dynamic>? ?? []);
        for (final opt in ops) {
          final oid = opt['id']?.toString() ?? '';
          if (oid.isNotEmpty) {
            _comfortScores.putIfAbsent(oid, () => 75.0);
            _selectedBidOptionId ??= oid;
          }
        }
      }
      _isLoading = false;
    });
  }

  Future<void> _castStandardVote(String optionId) async {
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    final res = await _tribusService.votarDecision(
      decisionId: widget.decisionId,
      optionId: optionId,
      voterHandle: widget.myHandle,
    );
    if (!mounted) return;
    setState(() {
      if (res != null) _decisionData = res;
      _isProcessing = false;
    });
    widget.onDecisionUpdated?.call();
  }

  Future<void> _submitLeastMiseryRatings(List<dynamic> opciones) async {
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    final Map<String, dynamic> ratingsPayload = {};
    for (final opt in opciones) {
      final oid = opt['id'].toString();
      final isVeto = _vetoedIds.contains(oid);
      final score = isVeto ? 0 : (_comfortScores[oid]?.round() ?? 75);
      ratingsPayload[oid] = {"score": score, "veto": isVeto};
    }

    final res = await _tribusService.votarDecision(
      decisionId: widget.decisionId,
      ratings: ratingsPayload,
      voterHandle: widget.myHandle,
    );
    if (!mounted) return;
    setState(() {
      if (res != null) _decisionData = res;
      _isProcessing = false;
    });
    widget.onDecisionUpdated?.call();
  }

  Future<void> _submitBlindBid() async {
    if (_selectedBidOptionId == null) return;
    final bid = int.tryParse(_bidController.text.trim()) ?? 0;
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    final res = await _tribusService.votarDecision(
      decisionId: widget.decisionId,
      optionId: _selectedBidOptionId,
      bidVinks: bid,
      voterHandle: widget.myHandle,
    );
    if (!mounted) return;
    setState(() {
      if (res != null) _decisionData = res;
      _isProcessing = false;
    });
    widget.onDecisionUpdated?.call();
  }

  Future<void> _resolverVotacion() async {
    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();
    final res = await _tribusService.resolverDecision(
      widget.decisionId,
      resolverHandle: widget.myHandle,
    );
    if (!mounted) return;
    setState(() {
      if (res != null) _decisionData = res;
      _isProcessing = false;
    });
    widget.onDecisionUpdated?.call();
    final summary = res?['resultado']?['summary']?.toString();
    if (summary != null && summary.isNotEmpty) {
      widget.onResolvedBroadcast?.call("⚖️ [VEREDICTO ZKA]: $summary");
    }
  }

  Widget _buildLeastMiseryVote(List<dynamic> opciones) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...opciones.map((opt) {
          final oid = opt['id'].toString();
          final isVetoed = _vetoedIds.contains(oid);
          final score = _comfortScores[oid] ?? 75.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: VinkiarColors.inkBlack,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isVetoed
                    ? VinkiarColors.panicRed
                    : VinkiarColors.aegisCyan.withOpacity(0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        opt['label']?.toString() ?? oid,
                        style: GoogleFonts.outfit(
                          color: isVetoed ? Colors.white54 : Colors.white,
                          fontSize: 12.5,
                          decoration: isVetoed ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: isVetoed
                            ? VinkiarColors.panicRed
                            : VinkiarColors.panicRed.withOpacity(0.16),
                        foregroundColor: isVetoed ? Colors.white : VinkiarColors.panicRed,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _isProcessing
                          ? null
                          : () {
                              setState(() {
                                if (isVetoed) {
                                  _vetoedIds.remove(oid);
                                } else {
                                  _vetoedIds.add(oid);
                                }
                              });
                            },
                      child: Text(
                        isVetoed ? "VETADO (SSC)" : "VETO SSC",
                        style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (!isVetoed) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        "Confort: ${score.round()}%",
                        style: GoogleFonts.jetBrainsMono(color: VinkiarColors.hackingGreen, fontSize: 9.5),
                      ),
                      Expanded(
                        child: Slider(
                          value: score,
                          min: 20,
                          max: 100,
                          divisions: 16,
                          activeColor: VinkiarColors.hackingGreen,
                          inactiveColor: Colors.white12,
                          onChanged: _isProcessing
                              ? null
                              : (v) => setState(() => _comfortScores[oid] = v),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: VinkiarColors.hackingGreen,
            foregroundColor: Colors.black,
          ),
          icon: const Icon(Icons.check, size: 16),
          label: Text(
            "REGISTRAR CONFORT / VETOS",
            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          onPressed: _isProcessing ? null : () => _submitLeastMiseryRatings(opciones),
        ),
      ],
    );
  }

  Widget _buildBlindAuctionVote(List<dynamic> opciones) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...opciones.map((opt) {
          final oid = opt['id'].toString();
          final selected = _selectedBidOptionId == oid;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: selected ? VinkiarColors.vertigoGold.withOpacity(0.18) : VinkiarColors.inkBlack,
                side: BorderSide(color: selected ? VinkiarColors.vertigoGold : Colors.white24),
                alignment: Alignment.centerLeft,
              ),
              onPressed: _isProcessing ? null : () => setState(() => _selectedBidOptionId = oid),
              child: Text(
                opt['label']?.toString() ?? oid,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 12.5),
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _bidController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: "Puja secreta (Ѵ)",
                  labelStyle: TextStyle(color: Colors.white60, fontSize: 10),
                  isDense: true,
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: VinkiarColors.vertigoGold,
                foregroundColor: Colors.black,
              ),
              onPressed: _isProcessing ? null : _submitBlindBid,
              child: Text("SELLAR PUJA", style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStandardVote(List<dynamic> opciones) {
    return Column(
      children: opciones.map((opt) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
              alignment: Alignment.centerLeft,
              side: BorderSide(color: VinkiarColors.aegisCyan.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _isProcessing ? null : () => _castStandardVote(opt['id'].toString()),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    opt['label']?.toString() ?? opt['id'].toString(),
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 12.5),
                  ),
                ),
                const Icon(Icons.how_to_vote, size: 16, color: VinkiarColors.aegisCyan),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _decisionData == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: VinkiarColors.panelDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: VinkiarColors.vertigoGold),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Sincronizando sesión: ${widget.fallbackTitle}...",
                style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 10),
              ),
            ),
          ],
        ),
      );
    }

    final d = _decisionData ?? {
      'id': widget.decisionId,
      'titulo': widget.fallbackTitle,
      'modo': widget.fallbackMode,
      'status': 'OPEN',
      'opciones': [],
      'resultado': {},
    };

    final String status = (d['status'] ?? 'OPEN').toString();
    final bool isOpen = status == 'OPEN';
    final String mode = (d['modo'] ?? widget.fallbackMode).toString();
    final List<dynamic> options = (d['opciones'] as List<dynamic>? ?? []);
    final Map<String, dynamic> resultado = Map<String, dynamic>.from(d['resultado'] as Map? ?? {});
    final int votersCount = (d['voters_count'] as num?)?.toInt() ?? 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VinkiarColors.panelDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOpen ? VinkiarColors.vertigoGold.withOpacity(0.8) : VinkiarColors.hackingGreen.withOpacity(0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: VinkiarColors.inkBlack, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  "$mode · $votersCount votos",
                  style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.refresh, color: Colors.white54, size: 15),
                onPressed: _loadDecision,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            d['titulo']?.toString() ?? widget.fallbackTitle,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          if ((d['descripcion'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(d['descripcion'].toString(), style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11.5, height: 1.3)),
          ],
          const SizedBox(height: 12),
          if (isOpen) ...[
            if (mode == 'LEAST_MISERY')
              _buildLeastMiseryVote(options)
            else if (mode == 'BLIND_AUCTION')
              _buildBlindAuctionVote(options)
            else
              _buildStandardVote(options),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: VinkiarColors.vertigoGold),
                icon: _isProcessing
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: VinkiarColors.vertigoGold))
                    : const Icon(Icons.gavel, size: 15),
                label: Text(
                  "CERRAR Y COMPUTAR VEREDICTO",
                  style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
                onPressed: _isProcessing ? null : _resolverVotacion,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (status == 'VETOED_ALL' ? VinkiarColors.panicRed : VinkiarColors.hackingGreen).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (status == 'VETOED_ALL' ? VinkiarColors.panicRed : VinkiarColors.hackingGreen).withOpacity(0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        status == 'VETOED_ALL' ? Icons.block : Icons.check_circle,
                        color: status == 'VETOED_ALL' ? VinkiarColors.panicRed : VinkiarColors.hackingGreen,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status == 'VETOED_ALL' ? "OPCIONES VETADAS (SSC)" : "VEREDICTO ALCANZADO",
                        style: GoogleFonts.jetBrainsMono(
                          color: status == 'VETOED_ALL' ? VinkiarColors.panicRed : VinkiarColors.hackingGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    resultado['summary']?.toString() ?? 'Decisión cerrada por el oráculo.',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 12.5, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
