-- Incorporate the professor details supplied after the initial roster migration.
update public.professors
set description = 'Enseña mejor que nadie, pero sus pruebas son imposibles. Genio de Big Tech y Netflix; fundó su propia empresa y cae genial en clase.'
where id = '00000000-0000-4000-8000-000000000010';
