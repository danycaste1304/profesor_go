-- Restore the organizers' warmer character descriptions. IDs, rarity, capture
-- rates and existing captures stay unchanged.
update public.professors as professor
set description = copy.description
from (values
  ('00000000-0000-4000-8000-000000000016'::uuid, 'Profe de MAC, amable y siempre dispuesto a ayudar. Apoya directamente al capítulo IEEE CIS y a quienes se animan a aprender.'),
  ('00000000-0000-4000-8000-000000000015'::uuid, 'Está a cargo de las maestrías en Ciencia de Datos e Inteligencia Artificial y domina el aprendizaje automático. Su aire serio impone respeto, pero es buena gente.'),
  ('00000000-0000-4000-8000-000000000014'::uuid, 'Súper buena gente y cercano en clase. Entre comunicaciones, IA y seguridad te hace disfrutar la materia, aunque puede ser letal cuando quiere.'),
  ('00000000-0000-4000-8000-000000000013'::uuid, 'Experto en redes y nuestro asesor de IEEE CS en la USFQ. Sus exámenes hacen temblar a muchos, pero enseña como nadie.'),
  ('00000000-0000-4000-8000-000000000012'::uuid, 'Profe de CMP y experto en IA. Desde el laboratorio encuentra cómo automatizar sus clases y hacerlas cada vez más interactivas.'),
  ('00000000-0000-4000-8000-000000000011'::uuid, 'Entre bases de datos y estructuras de datos, te impulsa a salir del aula, conocer gente y descubrir lo que hay más allá de las clases.'),
  ('00000000-0000-4000-8000-000000000009'::uuid, 'Coordina MAC y CMP. Entre aprendizaje automático, seguridad y optimización, cada clase puede convertirse en un experimento social.'),
  ('00000000-0000-4000-8000-000000000010'::uuid, 'Genio de Big Tech: da unas clases increíbles y pone exámenes que parecen imposibles. Aun así, acabas adorando la materia.'),
  ('00000000-0000-4000-8000-000000000017'::uuid, 'Profe de MAC. Encontrarlo puede ser una misión rara, pero cuando aparece llega con buena onda y siempre vale la pena escucharlo.'),
  ('00000000-0000-4000-8000-000000000018'::uuid, 'Profe de CMP, gentil y buena gente. Habla con él y puede que acabes metido en algún proyecto de programación o robótica.')
) as copy(id, description)
where professor.id = copy.id;

-- Physical NFC identifiers are registered through the private admin workflow.
-- Do not commit them to this public repository: they are replayable tokens.
