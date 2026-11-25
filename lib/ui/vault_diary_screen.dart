import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/vinkiar_secure_database.dart';
import 'theme.dart';

class VaultDiaryScreen extends StatefulWidget {
  const VaultDiaryScreen({Key? key}) : super(key: key);

  @override
  State<VaultDiaryScreen> createState() => _VaultDiaryScreenState();
}

class _VaultDiaryScreenState extends State<VaultDiaryScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await VinkiarSecureDatabase().getDiaryEntries();
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  void _showNewEntryModal() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VinkiarColors.abyssBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: VinkiarColors.aegisCyan, width: 1.5),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit_note, color: VinkiarColors.aegisCyan, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        "NUEVA ENTRADA // BITÁCORA",
                        style: GoogleFonts.jetBrainsMono(
                          color: VinkiarColors.aegisCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 16),
              Text(
                "Tus reflexiones son cifradas con SQLCipher. El Δ-Engine extraerá resonancias para deformar tu Eneagrama Vivo sin enviar datos fuera de tu búnker.",
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "Título (Ej. Registro de tensión o sesión de piel)",
                  hintStyle: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 11),
                  filled: true,
                  fillColor: VinkiarColors.panelDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentController,
                maxLines: 5,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: "Describe tu estado somático, límites negociados o contradicciones sentidas...",
                  hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 11),
                  filled: true,
                  fillColor: VinkiarColors.panelDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VinkiarColors.aegisCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Icon(Icons.fingerprint, size: 18),
                  label: Text(
                    saving ? "PROCESANDO RESONANCIA..." : "SELLAR EN BÓVEDA Y CALIBRAR Δ-ENGINE",
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final content = contentController.text.trim();
                          if (content.isEmpty) return;

                          setModalState(() => saving = true);

                          final deltas = await VinkiarSecureDatabase().saveDiaryEntry(
                            title: title.isEmpty ? "Entrada sin título" : title,
                            content: content,
                          );

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            _loadEntries();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: VinkiarColors.hackingGreen,
                                duration: const Duration(seconds: 4),
                                content: Text(
                                  "RESONANCIA PROYECTADA EN EL ENEAGRAMA VIVO",
                                  style: GoogleFonts.jetBrainsMono(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10.5),
                                ),
                              ),
                            );
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VinkiarColors.abyssBlack,
      appBar: AppBar(
        backgroundColor: VinkiarColors.panelDark,
        title: Text(
          "BITÁCORA CLANDESTINA",
          style: GoogleFonts.jetBrainsMono(
            color: VinkiarColors.aegisCyan,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: VinkiarColors.aegisCyan))
          : _entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.menu_book, color: Colors.white24, size: 54),
                        const SizedBox(height: 16),
                        Text(
                          "Tu Bitácora está vacía.\n\nEscribe reflexiones sobre tus sesiones, límites o vivencias íntimas para alimentar continuamente tu Eneagrama Vivo.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final item = _entries[index];
                    final date = item['timestamp']?.length > 16
                        ? item['timestamp'].substring(0, 16).replaceAll("T", " ")
                        : "";
                    final deltas = item['deltas'] as Map<String, dynamic>? ?? {};

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: VinkiarColors.panelDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item['title'],
                                  style: GoogleFonts.jetBrainsMono(
                                    color: VinkiarColors.vertigoGold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(date, style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 9)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: VinkiarColors.panicRed, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  await VinkiarSecureDatabase().deleteDiaryEntry(item['id']);
                                  _loadEntries();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item['content'],
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, height: 1.35),
                          ),
                          if (deltas.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              children: [
                                if ((deltas['empathy'] ?? 0) > 0)
                                  _buildDeltaBadge("+${deltas['empathy']} Empatía", VinkiarColors.aegisCyan),
                                if ((deltas['willpower'] ?? 0) > 0)
                                  _buildDeltaBadge("+${deltas['willpower']} Voluntad", VinkiarColors.vertigoGold),
                                if ((deltas['erotism'] ?? 0) > 0)
                                  _buildDeltaBadge("+${deltas['erotism']} Astucia", VinkiarColors.lotusPink),
                                if ((deltas['sovereignty'] ?? 0) > 0)
                                  _buildDeltaBadge("+${deltas['sovereignty']} Soberanía", VinkiarColors.hackingGreen),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: VinkiarColors.aegisCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add, size: 20),
        label: Text("ESCRIBIR NOTA", style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11)),
        onPressed: _showNewEntryModal,
      ),
    );
  }

  Widget _buildDeltaBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: GoogleFonts.jetBrainsMono(color: color, fontSize: 8.5, fontWeight: FontWeight.bold)),
    );
  }
}