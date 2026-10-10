// ============================================================================
//  © 2026 Zuhair Ibrahim — ALL RIGHTS RESERVED | جميع الحقوق محفوظة © زهير إبراهيم
//  ANTI-PIRACY OWNERSHIP GUARD — حارس الملكية الفكرية (منع انتحال الملكية)
//
//  This file contains ENCODED, non-severable ownership seals and is an
//  integral part of the proprietary license (see LICENSE file).
//
//  Removing, altering, obfuscating or bypassing this file or any seal
//  inside it is a DIRECT violation of the license and international
//  copyright law, and exposes the violator to legal action & DMCA takedown.
//
//  حذف أو تعديل أو تجاوز هذا الملف أو أي بصمة بداخله مخالفة مباشرة
//  للترخيص وقوانين حماية الملكية الفكرية الدولية، وتعرّض المخالف
//  للمساءلة القانونية وإشعارات الإزالة (DMCA).
// ============================================================================

/// Encoded ownership seal #1 — بصمة ملكية مشفّرة (لا تُحذف ولا تُعدّل).
const List<int> _sealA = <int>[79,87,78,69,82,58,90,117,104,97,105,114,45,73,98,114,97,104,105,109,124,80,82,79,74,69,67,84,58,97,99,99,111,117,110,116,105,110,103,115,121,115,116,101,109,124,89,69,65,82,58,50,48,50,54,124,76,73,67,69,78,83,69,58,65,76,76,45,82,73,71,72,84,83,45,82,69,83,69,82,86,69,68,124,83,73,71,58,90,73,45,50,48,50,54,45,65,67,67,45,80,82,79,80,82,73,69,84,65,82,89];

/// Encoded ownership seal #2 — بصمة ملكية مشفّرة (لا تُحذف ولا تُعدّل).
const List<int> _sealB = <int>[90,73,45,50,48,50,54,45,65,67,67,45,80,82,79,80,82,73,69,84,65,82,89];

String _d(List<int> codes) => String.fromCharCodes(codes);

/// Returns the decoded ownership signature — إثبات الملكية عند الطلب.
String ownershipSignature() => _d(_sealB);

/// Integrity self-check of the embedded ownership seals.
/// فحص ذاتي لسلامة بصمات الملكية المضمّنة.
bool ownershipSealsIntact() {
  final a = _d(_sealA);
  return a.startsWith('OWNER:Zuhair-Ibrahim') &&
      a.contains('ALL-RIGHTS-RESERVED') &&
      a.endsWith('|SIG:${_d(_sealB)}');
}
