import '../models/featured_professors.dart';
import '../models/professor.dart';
import '../models/rarity.dart';

/// Demo NFC tag seed row (mirrors `nfc_tags`, CONTRACTS §5).
class DemoTagSeed {
  const DemoTagSeed({
    required this.identifier,
    required this.professorId,
    this.active = true,
  });

  final String identifier;
  final String? professorId;
  final bool active;
}

String demoProfessorId(int n) =>
    '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

/// The 10 campus professors (CONTRACTS §5), fixed UUIDs.
final List<Professor> demoProfessors = List.unmodifiable([
  Professor(
    id: henryCarvajalId,
    name: 'Henry Carvajal',
    displayName: 'Prof. Henry',
    description: 'Profesor de Ingeniería en Matemáticas Aplicadas y Computación en la USFQ.',
    rarity: Rarity.common,
    baseCaptureRate: 0.80,
  ),
  Professor(
    id: felipeGrijalvaId,
    name: 'Felipe Grijalva',
    displayName: 'Prof. Felipe',
    description:
        'Coordinador de Ingeniería en Matemáticas Aplicadas y Computación. '
        'Dirige las maestrías en Ciencia de Datos e Inteligencia Artificial '
        'e investiga aprendizaje automático.',
    rarity: Rarity.epic,
    baseCaptureRate: 0.40,
  ),
  Professor(
    id: joseDavidVegaId,
    name: 'José David Vega',
    displayName: 'Prof. José David',
    description:
        'Profesor de Ciencias de la Computación. Investiga comunicaciones, '
        'aprendizaje automático y seguridad de la información.',
    rarity: Rarity.common,
    baseCaptureRate: 0.80,
  ),
  Professor(
    id: ricardoFloresId,
    name: 'Ricardo Flores',
    displayName: 'Prof. Ricardo',
    description:
        'Profesor e investigador en redes y seguridad de red. '
        'Asesora al capítulo de Computer Science de IEEE-USFQ.',
    rarity: Rarity.rare,
    baseCaptureRate: 0.60,
  ),
  Professor(
    id: pavelAlbaId,
    name: 'Pavel Alba',
    displayName: 'Prof. Pavel',
    description:
        'Profesor de Ingeniería en Ciencias de la Computación en la USFQ. '
        'Comparte su interés por la inteligencia artificial con estudiantes.',
    rarity: Rarity.epic,
    baseCaptureRate: 0.40,
  ),
  Professor(
    id: noelPerezId,
    name: 'Noel Pérez',
    displayName: 'Prof. Noel',
    description:
        'Profesor e investigador en minería de datos, aprendizaje '
        'automático y procesamiento de imágenes.',
    rarity: Rarity.epic,
    baseCaptureRate: 0.40,
  ),
  Professor(
    id: danielRiofrioId,
    name: 'Daniel Riofrío',
    displayName: 'Prof. Daniel',
    description:
        'Coordinador de Ingeniería en Ciencias de la Computación. '
        'Investiga aprendizaje automático, seguridad y optimización.',
    rarity: Rarity.legendary,
    baseCaptureRate: 0.25,
  ),
  Professor(
    id: erickNaunayId,
    name: 'Erick Ñauñay',
    displayName: 'Prof. Erick',
    description:
        'Invita a explorar retos de programación y nuevas ideas tecnológicas '
        'en Profesor GO.',
    rarity: Rarity.legendary,
    baseCaptureRate: 0.25,
  ),
  Professor(
    id: diegoMoralesId,
    name: 'Diego Morales',
    displayName: 'Prof. Diego',
    description:
        'Profesor de Ingeniería en Matemáticas Aplicadas y Computación '
        'en la USFQ.',
    rarity: Rarity.rare,
    baseCaptureRate: 0.60,
  ),
  Professor(
    id: robertoAndradeId,
    name: 'Roberto Andrade',
    displayName: 'Prof. Roberto',
    description:
        'Profesor de Ciencias de la Computación en la USFQ. '
        'Participa en proyectos de enseñanza de programación y robótica.',
    rarity: Rarity.common,
    baseCaptureRate: 0.80,
  ),
]);

/// DEMO-TAG-01..10 → the ten campus professors.
final List<DemoTagSeed> demoTagSeeds = List.unmodifiable([
  for (var n = 1; n <= 10; n++)
    DemoTagSeed(
      identifier: 'DEMO-TAG-${n.toString().padLeft(2, '0')}',
      professorId: switch (n) {
        1 => henryCarvajalId,
        2 => felipeGrijalvaId,
        3 => joseDavidVegaId,
        4 => ricardoFloresId,
        5 => pavelAlbaId,
        6 => noelPerezId,
        7 => danielRiofrioId,
        8 => erickNaunayId,
        9 => diegoMoralesId,
        10 => robertoAndradeId,
        _ => null,
      },
    ),
]);

Professor? demoProfessorById(String? id) {
  if (id == null) return null;
  for (final p in demoProfessors) {
    if (p.id == id) return p;
  }
  return null;
}
