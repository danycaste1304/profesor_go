"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export type QrActionResult = { url?: string; error?: string };

const GAME_URL = process.env.NEXT_PUBLIC_GAME_URL;

export async function rotateProfessorQr(professorId: string): Promise<QrActionResult> {
  let url: URL;
  try {
    if (!GAME_URL) throw new Error("GAME_URL_REQUIRED");
    url = new URL(GAME_URL);
    if (url.protocol !== "https:") throw new Error("HTTPS_REQUIRED");
  } catch {
    return { error: "NEXT_PUBLIC_GAME_URL debe ser una URL HTTPS válida." };
  }
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_rotate_professor_qr", {
    p_professor_id: professorId,
  });
  if (error || typeof data !== "string") {
    return { error: error?.message ?? "No se pudo crear el QR." };
  }
  // The fragment never reaches the web server or its access logs.
  url.hash = `qr=${data}`;
  revalidatePath("/qr");
  return { url: url.toString() };
}

export async function setProfessorQrActive(
  professorId: string,
  active: boolean,
): Promise<QrActionResult> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_set_professor_qr_active", {
    p_professor_id: professorId,
    p_active: active,
  });
  if (error || data !== true) return { error: error?.message ?? "No se encontró el QR." };
  revalidatePath("/qr");
  return {};
}
