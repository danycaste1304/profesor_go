-- Align the ten live profiles with institutional roles and neutral game copy.
-- Keep IDs, rarity, capture rates and NFC mappings unchanged.
update public.professors as professor
set name = reviewed.name,
    display_name = reviewed.display_name,
    description = reviewed.description
from (values
  ('00000000-0000-4000-8000-000000000016'::uuid, 'Henry Carvajal', 'Prof. Henry', 'Profesor de Ingeniería en Matemáticas Aplicadas y Computación en la USFQ.'),
  ('00000000-0000-4000-8000-000000000015'::uuid, 'Felipe Grijalva', 'Prof. Felipe', 'Coordinador de Ingeniería en Matemáticas Aplicadas y Computación. Dirige las maestrías en Ciencia de Datos e Inteligencia Artificial e investiga aprendizaje automático.'),
  ('00000000-0000-4000-8000-000000000014'::uuid, 'José David Vega', 'Prof. José David', 'Profesor de Ciencias de la Computación. Investiga comunicaciones, aprendizaje automático y seguridad de la información.'),
  ('00000000-0000-4000-8000-000000000013'::uuid, 'Ricardo Flores', 'Prof. Ricardo', 'Profesor e investigador en redes y seguridad de red. Asesora al capítulo de Computer Science de IEEE-USFQ.'),
  ('00000000-0000-4000-8000-000000000012'::uuid, 'Pavel Alba', 'Prof. Pavel', 'Profesor de Ingeniería en Ciencias de la Computación en la USFQ. Comparte su interés por la inteligencia artificial con estudiantes.'),
  ('00000000-0000-4000-8000-000000000011'::uuid, 'Noel Pérez', 'Prof. Noel', 'Profesor e investigador en minería de datos, aprendizaje automático y procesamiento de imágenes.'),
  ('00000000-0000-4000-8000-000000000009'::uuid, 'Daniel Riofrío', 'Prof. Daniel', 'Coordinador de Ingeniería en Ciencias de la Computación. Investiga aprendizaje automático, seguridad y optimización.'),
  ('00000000-0000-4000-8000-000000000010'::uuid, 'Erick Ñauñay', 'Prof. Erick', 'Invita a explorar retos de programación y nuevas ideas tecnológicas en Profesor GO.'),
  ('00000000-0000-4000-8000-000000000017'::uuid, 'Diego Morales', 'Prof. Diego', 'Profesor de Ingeniería en Matemáticas Aplicadas y Computación en la USFQ.'),
  ('00000000-0000-4000-8000-000000000018'::uuid, 'Roberto Andrade', 'Prof. Roberto', 'Profesor de Ciencias de la Computación en la USFQ. Participa en proyectos de enseñanza de programación y robótica.')
) as reviewed(id, name, display_name, description)
where professor.id = reviewed.id;
