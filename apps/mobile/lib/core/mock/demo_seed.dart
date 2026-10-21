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
    description: 'Profesor de MAC, amable y buena onda con sus estudiantes.',
    rarity: Rarity.common,
    baseCaptureRate: 0.80,
  ),
  Professor(
    id: felipeGrijalvaId,
    name: 'Felipe Grijalva',
    displayName: 'Prof. Felipe',
    description:
        'Excoordinador de MAC y experto en Machine Learning. '
        'Está a cargo de las maestrías de Ciencia de Datos e IA. '
        'Su aire serio impone respeto, pero es buena gente.',
    rarity: Rarity.epic,
    baseCaptureRate: 0.40,
  ),
  Professor(
    id: joseDavidVegaId,
    name: 'Jose David Vega',
    displayName: 'Prof. Jose David',
    description:
        'Enseña muy bien y sus materias son llevaderas. '
        'Es un profe muy buena onda, cercano y querido por sus estudiantes.',
    rarity: Rarity.common,
    baseCaptureRate: 0.80,
  ),
  Professor(
    id: ricardoFloresId,
    name: 'Ricardo Flores',
    displayName: 'Prof. Ricardo',
    description:
        'Experto en Redes y nuestro advisor de CS. Sus exámenes son '
        'legendariamente difíciles, pero explica muy bien.',
    rarity: Rarity.rare,
    baseCaptureRate: 0.60,
  ),
  Professor(
    id: pavelAlbaId,
    name: 'Pavel Alba',
    displayName: 'Prof. Pavel',
    description:
        'Experto en Inteligencia Artificial y el «papá de la carrera». '
        'Su oficina está en nuestro laboratorio; explica increíble y '
        'hace sus clases súper interactivas.',
    rarity: Rarity.epic,
    baseCaptureRate: 0.40,
  ),
  Professor(
    id: noelPerezId,
    name: 'Noel Perez',
    displayName: 'Prof. Noel',
    description:
        'Profesor cubano de Bases de Datos y Estructuras de Datos. '
        'Sus exámenes son retadores; enseña bien y anima a sus estudiantes '
        'a ser más sociables.',
    rarity: Rarity.epic,
    baseCaptureRate: 0.40,
  ),
  Professor(
    id: danielRiofrioId,
    name: 'Daniel Riofrio',
    displayName: 'Prof. Daniel',
    description:
        'Coordinador de MAC y CMP. «Todo es un experimento social». '
        'Uno de los profesores más poderosos e inteligentes del campus.',
    rarity: Rarity.legendary,
    baseCaptureRate: 0.25,
  ),
  Professor(
    id: erickNaunayId,
    name: 'Erick Ñauñay',
    displayName: 'Prof. Erick',
    description:
        'Enseña mejor que nadie, pero sus pruebas son imposibles. '
        'Genio de Big Tech y Netflix; fundó su propia empresa y cae genial en clase.',
    rarity: Rarity.legendary,
    baseCaptureRate: 0.25,
  ),
  Professor(
    id: diegoMoralesId,
    name: 'Diego Morales',
    displayName: 'Prof. Diego',
    description:
        'Profesor de MAC. Es tan difícil encontrárselo que aquí aparece como raro. '
        'Cuando se deja ver, llega con buena onda.',
    rarity: Rarity.rare,
    baseCaptureRate: 0.60,
  ),
  Professor(
    id: robertoAndradeId,
    name: 'Roberto Andrade',
    displayName: 'Prof. Roberto',
    description: 'Profesor de CMP. Gentil, sencillo y muy buena gente con sus estudiantes.',
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
