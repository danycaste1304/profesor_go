"use server";

import { revalidatePath } from "next/cache";
import { getSupabaseEnv } from "@/lib/supabase/env";
import { createClient } from "@/lib/supabase/server";
import { interpretWrite } from "@/lib/writes";
import type { NfcFormState } from "@/lib/types";

interface EdgeErrorBody {
  error?: string;
  message?: string;
}

interface EdgeSuccessBody {
  tag?: { id: string; tag_identifier: string; professor_id: string | null; active: boolean };
}

/**
 * Creates or re-associates a tag through the `admin-register-nfc` Edge Function
 * (CONTRACTS §4), authenticated with the signed-in admin's access token.
 */
export async function registerNfcTag(_prev: NfcFormState, formData: FormData): Promise<NfcFormState> {
  const tag_identifier = String(formData.get("tag_identifier") ?? "").trim();
  const professor_id = String(formData.get("professor_id") ?? "").trim();
  const active = formData.get("active") === "on";
  const values = { tag_identifier, professor_id, active };

  if (!tag_identifier) {
    return { values, error: "Introduce el identificador del tag." };
  }

  const supabase = await createClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();
  if (!session) {
    return { values, error: "La sesión ha caducado. Vuelve a iniciar sesión." };
  }

  const { url, anonKey } = getSupabaseEnv();
  let response: Response;
  try {
    response = await fetch(`${url}/functions/v1/admin-register-nfc`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${session.access_token}`,
        apikey: anonKey,
      },
      body: JSON.stringify({ tag_identifier, professor_id: professor_id || null, active }),
      cache: "no-store",
    });
  } catch {
    return { values, error: "No se pudo contactar con la función admin-register-nfc." };
  }

  const body = (await response.json().catch(() => null)) as (EdgeErrorBody & EdgeSuccessBody) | null;
  if (!response.ok) {
    const code = body?.error ?? `HTTP ${response.status}`;
    return { values, error: body?.message ? `${body.message} (${code})` : `Error al registrar el tag (${code}).` };
  }

  revalidatePath("/nfc");
  return { success: `Tag «${body?.tag?.tag_identifier ?? tag_identifier}» guardado correctamente.` };
}

/** Toggles `nfc_tags.active` directly (admin RLS). Bound from the list as a form action. */
export async function setNfcTagActive(id: string, active: boolean): Promise<void> {
  const supabase = await createClient();
  // `.select("id")`: PostgREST returns no error when the UPDATE matches zero rows,
  // so without the returned rows a toggle on a deleted/filtered tag looks successful.
  const written = interpretWrite(
    await supabase.from("nfc_tags").update({ active }).eq("id", id).select("id"),
    "actualizar",
    "el tag NFC",
  );
  if (!written.ok) {
    throw new Error(written.message);
  }
  revalidatePath("/nfc");
}
