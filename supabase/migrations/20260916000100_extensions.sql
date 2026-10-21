-- Profesor GO — extensions
-- pgcrypto: gen_random_uuid(), crypt()/gen_salt() for the local demo users in seed.sql.
-- postgis: prepared for future geo features (campus map); no geo columns exist yet.
create extension if not exists pgcrypto with schema extensions;
create extension if not exists postgis with schema extensions;
