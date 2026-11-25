import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/vinkiar_secure_database.dart';

typedef JsonMap = Map<String, dynamic>;

class MascaraPublicaData {
  final String avatarId;
  final String bio;
  final String edad;
  final String sexo;
  final String identidadSexual;
  final String objetivos;
  final String contratoPublico;
  final bool mostrarEdad;
  final bool mostrarSexo;
  final bool mostrarIdentidad;
  final bool mostrarObjetivos;
  final bool mostrarEstadisticas;
  final bool mostrarMedallas;

  MascaraPublicaData({
    this.avatarId = 'CENTINELA_01',
    this.bio = 'Explorando conexiones reales fuera del ruido algorítmico.',
    this.edad = '',
    this.sexo = '',
    this.identidadSexual = '',
    this.objetivos = 'Amistades profundas y ocio analógico',
    this.contratoPublico = 'Café sin pantallas de 20 min en cualquier Santuario cercano.',
    this.mostrarEdad = false,
    this.mostrarSexo = false,
    this.mostrarIdentidad = false,
    this.mostrarObjetivos = true,
    this.mostrarEstadisticas = true,
    this.mostrarMedallas = true,
  });

  JsonMap toJson() => {
        'avatarId': avatarId,
        'bio': bio,
        'edad': edad,
        'sexo': sexo,
        'identidadSexual': identidadSexual,
        'objetivos': objetivos,
        'contratoPublico': contratoPublico,
        'mostrarEdad': mostrarEdad,
        'mostrarSexo': mostrarSexo,
        'mostrarIdentidad': mostrarIdentidad,
        'mostrarObjetivos': mostrarObjetivos,
        'mostrarEstadisticas': mostrarEstadisticas,
        'mostrarMedallas': mostrarMedallas,
      };

  factory MascaraPublicaData.fromJson(JsonMap json) {
    return MascaraPublicaData(
      avatarId: json['avatarId']?.toString() ?? 'CENTINELA_01',
      bio: json['bio']?.toString() ?? '',
      edad: json['edad']?.toString() ?? '',
      sexo: json['sexo']?.toString() ?? '',
      identidadSexual: json['identidadSexual']?.toString() ?? '',
      objetivos: json['objetivos']?.toString() ?? '',
      contratoPublico: json['contratoPublico']?.toString() ?? '',
      mostrarEdad: json['mostrarEdad'] == true,
      mostrarSexo: json['mostrarSexo'] == true,
      mostrarIdentidad: json['mostrarIdentidad'] == true,
      mostrarObjetivos: json['mostrarObjetivos'] ?? true,
      mostrarEstadisticas: json['mostrarEstadisticas'] ?? true,
      mostrarMedallas: json['mostrarMedallas'] ?? true,
    );
  }
}

class MascaraPublicaScreen extends StatefulWidget {
  final String handle;
  final String archetype;
  final int level;
  final double reputationScore;

  const MascaraPublicaScreen({
    super.key,
    required this.handle,
    required this.archetype,
    this.level = 1,
    this.reputationScore = 0.95,
  });

  @override
  State<MascaraPublicaScreen> createState() => _MascaraPublicaScreenState();
}

class _MascaraPublicaScreenState extends State<MascaraPublicaScreen> {
  final List<JsonMap> _avataresDisponibles = [
    {'id': 'CENTINELA_01', 'label': 'Centinela', 'icon': Icons.shield_outlined, 'color': const Color(0xFF00E5FF)},
    {'id': 'ILUSIONISTA_01', 'label': 'Ilusionista', 'icon': Icons.auto_awesome, 'color': const Color(0xFFF472B6)},
    {'id': 'BARDO_01', 'label': 'Bardo ZKA', 'icon': Icons.graphic_eq, 'color': const Color(0xFFE5B869)},
    {'id': 'OPERADOR_01', 'label': 'Operador', 'icon': Icons.terminal, 'color': const Color(0xFF39FF14)},
  ];

  late String _avatarId;
  late TextEditingController _bioCtrl;
  late TextEditingController _edadCtrl;
  late TextEditingController _sexoCtrl;
  late TextEditingController _identidadCtrl;
  late TextEditingController _objetivosCtrl;
  late TextEditingController _contratoCtrl;

  bool _mostrarEdad = false;
  bool _mostrarSexo = false;
  bool _mostrarIdentidad = false;
  bool _mostrarObjetivos = true;
  bool _mostrarEstadisticas = true;
  bool _mostrarMedallas = true;

  @override
  void initState() {
    super.initState();
    _avatarId = 'CENTINELA_01';
    _bioCtrl = TextEditingController();
    _edadCtrl = TextEditingController();
    _sexoCtrl = TextEditingController();
    _identidadCtrl = TextEditingController();
    _objetivosCtrl = TextEditingController();
    _contratoCtrl = TextEditingController();
    _loadData();
  }

  Future<void> _loadData() async {
    final avatar = await VinkiarSecureDatabase().getAvatarSheet("LOCAL_USER");
    final stats = avatar?['stats'] as JsonMap? ?? {};
    final raw = stats['mascara_publica'];

    MascaraPublicaData data;
    if (raw is String && raw.isNotEmpty) {
      data = MascaraPublicaData.fromJson(jsonDecode(raw));
    } else if (raw is Map) {
      data = MascaraPublicaData.fromJson(JsonMap.from(raw));
    } else {
      data = MascaraPublicaData(
        bio: stats['bio']?.toString() ?? 'Explorando conexiones reales fuera del ruido algorítmico.',
      );
    }

    if (!mounted) return;
    setState(() {
      _avatarId = data.avatarId;
      _bioCtrl.text = data.bio;
      _edadCtrl.text = data.edad;
      _sexoCtrl.text = data.sexo;
      _identidadCtrl.text = data.identidadSexual;
      _objetivosCtrl.text = data.objetivos;
      _contratoCtrl.text = data.contratoPublico;
      _mostrarEdad = data.mostrarEdad;
      _mostrarSexo = data.mostrarSexo;
      _mostrarIdentidad = data.mostrarIdentidad;
      _mostrarObjetivos = data.mostrarObjetivos;
      _mostrarEstadisticas = data.mostrarEstadisticas;
      _mostrarMedallas = data.mostrarMedallas;
    });
  }

  Future<void> _saveData() async {
    final model = MascaraPublicaData(
      avatarId: _avatarId,
      bio: _bioCtrl.text.trim(),
      edad: _edadCtrl.text.trim(),
      sexo: _sexoCtrl.text.trim(),
      identidadSexual: _identidadCtrl.text.trim(),
      objetivos: _objetivosCtrl.text.trim(),
      contratoPublico: _contratoCtrl.text.trim(),
      mostrarEdad: _mostrarEdad,
      mostrarSexo: _mostrarSexo,
      mostrarIdentidad: _mostrarIdentidad,
      mostrarObjetivos: _mostrarObjetivos,
      mostrarEstadisticas: _mostrarEstadisticas,
      mostrarMedallas: _mostrarMedallas,
    );

    await VinkiarSecureDatabase().updateAvatarData({
      'mascara_publica': jsonEncode(model.toJson()),
      'bio': _bioCtrl.text.trim(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Máscara Pública sellada en tu Bóveda cifrada ZKA.'),
        backgroundColor: Color(0xFF10121A),
      ),
    );
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _edadCtrl.dispose();
    _sexoCtrl.dispose();
    _identidadCtrl.dispose();
    _objetivosCtrl.dispose();
    _contratoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedAvatar = _avataresDisponibles.firstWhere(
      (a) => a['id'] == _avatarId,
      orElse: () => _avataresDisponibles.first,
    );
    final Color avColor = selectedAvatar['color'] as Color;

    return Scaffold(
      backgroundColor: const Color(0xFF08090C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10121A),
        title: const Text('MÁSCARA PÚBLICA // ZKA', style: TextStyle(fontFamily: 'monospace', fontSize: 15)),
        actions: [
          TextButton.icon(
            onPressed: _saveData,
            icon: const Icon(Icons.save, color: Color(0xFF39FF14), size: 18),
            label: const Text('GUARDAR', style: TextStyle(color: Color(0xFF39FF14), fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10121A),
              border: Border.all(color: avColor.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('VISTA PREVIA EN RADAR (CAPA EXTERNA)', style: TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: avColor.withValues(alpha: 0.15),
                      child: Icon(selectedAvatar['icon'] as IconData, color: avColor, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.handle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          Text(widget.archetype, style: TextStyle(color: avColor, fontSize: 11, fontFamily: 'monospace')),
                          if (_mostrarEstadisticas)
                            Text(
                              'Nivel ${widget.level} · Reputación ${(widget.reputationScore * 100).toInt()}%',
                              style: const TextStyle(color: Color(0xFFE5B869), fontSize: 10.5, fontFamily: 'monospace'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_bioCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_bioCtrl.text, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                ],
                if (_mostrarObjetivos && _objetivosCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('🎯 Busca: ${_objetivosCtrl.text}', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontFamily: 'monospace')),
                ],
                if (_contratoCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF08090C), borderRadius: BorderRadius.circular(4)),
                    child: Text('⚔️ Contrato Público: ${_contratoCtrl.text}', style: const TextStyle(color: Color(0xFFE5B869), fontSize: 11, fontFamily: 'monospace')),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text('1. ASPECTO DE ARQUETIPO', style: TextStyle(color: Color(0xFFE5B869), fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _avataresDisponibles.map((av) {
              final bool sel = av['id'] == _avatarId;
              final Color c = av['color'] as Color;
              return ChoiceChip(
                label: Text(av['label'] as String, style: TextStyle(color: sel ? Colors.black : Colors.white70, fontFamily: 'monospace', fontSize: 11)),
                selected: sel,
                selectedColor: c,
                backgroundColor: const Color(0xFF10121A),
                onSelected: (_) => setState(() => _avatarId = av['id'] as String),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),
          const Text('2. PRESENTACIÓN Y CONTRATO PÚBLICO', style: TextStyle(color: Color(0xFFE5B869), fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildInput(_bioCtrl, 'Manifiesto / Presentación personal', maxLines: 2),
          const SizedBox(height: 10),
          _buildInput(_contratoCtrl, 'Contrato público ofertado en Radar (ej. Taza de té sin pantallas)', maxLines: 2),

          const SizedBox(height: 18),
          const Text('3. VISIBILIDAD SELECTIVA DE DATOS', style: TextStyle(color: Color(0xFFE5B869), fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
          _buildToggleField('Objetivos relacionales', _objetivosCtrl, _mostrarObjetivos, (v) => setState(() => _mostrarObjetivos = v)),
          _buildToggleField('Edad', _edadCtrl, _mostrarEdad, (v) => setState(() => _mostrarEdad = v)),
          _buildToggleField('Sexo', _sexoCtrl, _mostrarSexo, (v) => setState(() => _mostrarSexo = v)),
          _buildToggleField('Identidad / Orientación', _identidadCtrl, _mostrarIdentidad, (v) => setState(() => _mostrarIdentidad = v)),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar Nivel e Índice Reputacional', style: TextStyle(color: Colors.white, fontSize: 13)),
            value: _mostrarEstadisticas,
            activeColor: const Color(0xFF39FF14),
            onChanged: (v) => setState(() => _mostrarEstadisticas = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar Medallas Obtenidas', style: TextStyle(color: Colors.white, fontSize: 13)),
            value: _mostrarMedallas,
            activeColor: const Color(0xFF39FF14),
            onChanged: (v) => setState(() => _mostrarMedallas = v),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF10121A),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1C1F26))),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E5FF))),
      ),
    );
  }

  Widget _buildToggleField(String title, TextEditingController ctrl, bool visible, ValueChanged<bool> onToggle) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(child: _buildInput(ctrl, title)),
          const SizedBox(width: 8),
          Column(
            children: [
              const Text('Público', style: TextStyle(color: Colors.white54, fontSize: 9, fontFamily: 'monospace')),
              Switch(
                value: visible,
                activeColor: const Color(0xFF00E5FF),
                onChanged: onToggle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}