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

/// The campus professors (CONTRACTS §5), fixed UUIDs.
final List<Professor> demoProfessors = List.unmodifiable([
  Professor(
    id: henryCarvajalId,
    name: 'Henry Carvajal',
    displayName: 'Prof. Henry',
    description:
        'Profe de MAC, amable y siempre dispuesto a ayudar. Apoya directamente '
        'al capítulo IEEE CIS y a quienes se animan a aprender.',
    rarity: Rarity.common,
    baseCaptureRate: 0.80,
  ),
  Professor(
    id: felipeGrijalvaId,
    name: 'Felipe Grijalva',
    displayName: 'Prof. Felipe',
    description:
        'Está a cargo de las maestrías en Ciencia de Datos e Inteligencia '
        'Artificial y domina el aprendizaje automático. Su aire serio impone '
        'respeto, pero es buena gente.',
    rarity: Rarity.epic,
    baseCaptureRate: 0.40,
  ),
  Professor(
    id: joseDavidVegaId,
    name: 'José David Vega',
    displayName: 'Prof. José David',
    description:
        'Súper buena gente y cercano en clase. Entre comunicaciones, IA y '
        'seguridad te hace disfrutar la materia, aunque puede ser letal '
        'cuando quiere.',
    rarity: Rarity.common,
    baseCaptureRate: 0.80,
  ),
  Professor(
    id: ricardoFloresId,
    name: 'Ricardo Flores',
    displayName: 'Prof. Ricardo',
    description:
        'Experto en redes y nuestro asesor de IEEE CS en la USFQ. Sus '
        'exámenes hacen temblar a muchos, pero enseña como nadie.',
    rarity: Rarity.rare,
    baseCaptureRate: 0.60,
  ),
  Professor(
    id: pavelAlbaId,
    name: 'Pavel Alba',
    displayName: 'Prof. Pavel',
    description:
        'Profe de CMP y experto en IA. Desde el laboratorio encuentra cómo '
        'automatizar sus clases y hacerlas cada vez más interactivas.',
    rarity: Rarity.epic,
    baseCaptureRate: 0.40,
  ),
  Professor(
    id: noelPerezId,
    name: 'Noel Pérez',
    displayName: 'Prof. Noel',
    description:
        'Entre bases de datos y estructuras de datos, te impulsa a salir del '
        'aula, conocer gente y descubrir lo que hay más allá de las clases.',
    rarity: Rarity.epic,
    baseCaptureRate: 0.40,
  ),
  Professor(
    id: danielRiofrioId,
    name: 'Daniel Riofrío',
    displayName: 'Prof. Daniel',
    description:
        'Coordina MAC y CMP. Entre aprendizaje automático, seguridad y '
        'optimización, cada clase puede convertirse en un experimento social.',
    rarity: Rarity.legendary,
    baseCaptureRate: 0.25,
  ),
  Professor(
    id: erickNaunayId,
    name: 'Erick Ñauñay',
    displayName: 'Prof. Erick',
    description:
        'Genio de Big Tech: da unas clases increíbles y pone exámenes que '
        'parecen imposibles. Aun así, acabas adorando la materia.',
    rarity: Rarity.legendary,
    baseCaptureRate: 0.25,
  ),
  Professor(
    id: diegoMoralesId,
    name: 'Diego Morales',
    displayName: 'Prof. Diego',
    description:
        'Profe de MAC. Encontrarlo puede ser una misión rara, pero cuando '
        'aparece llega con buena onda y siempre vale la pena escucharlo.',
    rarity: Rarity.rare,
    baseCaptureRate: 0.60,
  ),
  Professor(
    id: robertoAndradeId,
    name: 'Roberto Andrade',
    displayName: 'Prof. Roberto',
    description:
        'Profe de CMP, gentil y buena gente. Habla con él y puede que acabes '
        'metido en algún proyecto de programación o robótica.',
    rarity: Rarity.common,
    baseCaptureRate: 0.80,
  ),
  // Inscritos por el formulario (fiesta Némesis).
  Professor(
    id: patricioRojasId,
    name: 'Patricio Rojas',
    displayName: 'Pato',
    description: 'Profe de Biotecnología.',
    rarity: Rarity.common,
    baseCaptureRate: 0.80,
  ),
  Professor(
    id: edisonLozaId,
    name: 'Edison Loza',
    displayName: 'El Eddy',
    description: 'Profe de Administración de Empresas.',
    rarity: Rarity.common,
    baseCaptureRate: 0.80,
  ),
  Professor(
    id: soniaKraemerId,
    name: 'Sonia Kraemer',
    displayName: 'Sonia',
    description: 'Profe de Artes Liberales.',
    rarity: Rarity.common,
    baseCaptureRate: 0.80,
  ),
  Professor(
    id: washingtonLomasId,
    name: 'Washington Lomas',
    displayName: 'Washo',
    description: 'Profe de Física.',
    rarity: Rarity.common,
    baseCaptureRate: 0.80,
  ),
  Professor(
    id: rodrigoMunozId,
    name: 'Rodrigo Muñoz',
    displayName: 'Rod',
    description: 'Profe de Diseño Comunicacional.',
    rarity: Rarity.common,
    baseCaptureRate: 0.80,
  ),
  Professor(
    id: ximenaFerroId,
    name: 'Ximena Ferro',
    displayName: 'LaXime',
    description: 'Profe de Publicidad.',
    rarity: Rarity.common,
    baseCaptureRate: 0.80,
  ),
]);

/// DEMO-TAG-01..16 → the campus professors.
final List<DemoTagSeed> demoTagSeeds = List.unmodifiable([
  for (var n = 1; n <= 16; n++)
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
        11 => patricioRojasId,
        12 => edisonLozaId,
        13 => soniaKraemerId,
        14 => washingtonLomasId,
        15 => rodrigoMunozId,
        16 => ximenaFerroId,
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
