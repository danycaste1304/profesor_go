// Edge Function `admin-register-nfc` (CONTRACTS §4).
// Business logic lives in ./handler.ts so it can be unit-tested without starting a server.
import { asDb, createServiceClient } from "../_shared/supabase.ts";
import { createHttpHandler, handleAdminRegisterNfc } from "./handler.ts";

export { handleAdminRegisterNfc };

const client = createServiceClient();
const db = asDb(client);

Deno.serve(createHttpHandler({ db, auth: client.auth }));
