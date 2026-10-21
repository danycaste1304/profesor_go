// Edge Function `resolve-capture` (CONTRACTS §4, §9, §10).
// Business logic lives in ./handler.ts so it can be unit-tested without starting a server.
import { secureRandom } from "../_shared/random.ts";
import { asDb, createServiceClient } from "../_shared/supabase.ts";
import { createHttpHandler, handleResolveCapture } from "./handler.ts";

export { handleResolveCapture };

const client = createServiceClient();
const db = asDb(client);

Deno.serve(createHttpHandler({ db, auth: client.auth, random: secureRandom }));
