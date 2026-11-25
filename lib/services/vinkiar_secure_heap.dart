import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

typedef AllocateFunc = Pointer<Char> Function(Int32 size);
typedef AllocateFuncDart = Pointer<Char> Function(int size);

typedef WipeFunc = Void Function(Pointer<Char> buffer, Int32 size);
typedef WipeFuncDart = void Function(Pointer<Char> buffer, int size);

class VinkiarSecureHeap {
  static final VinkiarSecureHeap _instance = VinkiarSecureHeap._internal();
  factory VinkiarSecureHeap() => _instance;
  VinkiarSecureHeap._internal();

  DynamicLibrary? _nativeLib;
  AllocateFuncDart? _allocate;
  WipeFuncDart? _wipeAndFree;
  bool _isNativeLoaded = false;

  void init() {
    try {
      if (Platform.isAndroid) {
        _nativeLib = DynamicLibrary.open('libvinkiar_secure_heap.so');
        _allocate = _nativeLib!
            .lookup<NativeFunction<AllocateFunc>>('vinkiar_allocate_secure_buffer')
            .asFunction<AllocateFuncDart>();
        _wipeAndFree = _nativeLib!
            .lookup<NativeFunction<WipeFunc>>('vinkiar_wipe_and_free')
            .asFunction<WipeFuncDart>();
        _isNativeLoaded = true;
        print("VINKIAR_SECURITY: Librería nativa C++ secure_heap cargada con éxito.");
      } else {
        print("VINKIAR_SECURITY: Plataforma no soportada para FFI nativo. Usando fallback de Dart.");
      }
    } catch (e) {
      print("VINKIAR_SECURITY_WARNING: Error al cargar librería nativa, usando fallback: $e");
      _isNativeLoaded = false;
    }
  }

  /// Asigna un búfer seguro. Devuelve un puntero nativo si FFI está activo,
  /// o un Uint8List si está en modo fallback.
  dynamic allocate(int size) {
    if (_isNativeLoaded && _allocate != null) {
      return _allocate!(size);
    } else {
      return Uint8List(size);
    }
  }

  /// Libera y sobrescribe el búfer.
  void free(dynamic buffer, int size) {
    if (_isNativeLoaded && _wipeAndFree != null && buffer is Pointer<Char>) {
      _wipeAndFree!(buffer, size);
    } else if (buffer is Uint8List) {
      // Fallback de Dart: Sobrescribe físicamente con ceros
      for (int i = 0; i < buffer.length; i++) {
        buffer[i] = 0;
      }
    }
  }

  /// Convierte un String sensible a un buffer nativo o Uint8List
  dynamic stringToSecureBuffer(String text) {
    final bytes = Uint8List.fromList(text.codeUnits);
    final buffer = allocate(bytes.length);
    if (buffer is Pointer<Char>) {
      for (int i = 0; i < bytes.length; i++) {
        buffer.cast<Uint8>()[i] = bytes[i];
      }
    } else if (buffer is Uint8List) {
      buffer.setAll(0, bytes);
    }
    return buffer;
  }

  /// Recupera un String de un buffer seguro (temporalmente)
  String secureBufferToString(dynamic buffer, int size) {
    final List<int> charCodes = [];
    if (buffer is Pointer<Char>) {
      final uint8Ptr = buffer.cast<Uint8>();
      for (int i = 0; i < size; i++) {
        charCodes.add(uint8Ptr[i]);
      }
    } else if (buffer is Uint8List) {
      charCodes.addAll(buffer.take(size));
    }
    return String.fromCharCodes(charCodes);
  }
}
