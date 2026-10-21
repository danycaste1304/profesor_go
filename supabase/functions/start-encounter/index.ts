// Edge Function `start-encounter` (CONTRACTS §4, §10).
// Business logic lives in ./handler.ts so it can be unit-tested without starting a server.
import { loadAppSettings } from "../_shared/settings.ts";
import { asDb, createServiceClient } from "../_shared/supabase.ts";
import { createHttpHandler, handleStartEncounter } from "./handler.ts";

export { handleStartEncounter };

const client = createServiceClient();
const db = asDb(client);

Deno.serve(
  createHttpHandler({
    db,
    auth: client.auth,
    now: () => new Date(),
    loadSettings: () => loadAppSettings(db),
  }),
);
