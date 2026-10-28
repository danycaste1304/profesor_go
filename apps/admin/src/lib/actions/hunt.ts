"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export interface HuntAssignmentState {
  error?: string;
  success?: string;
  values?: { professor_id: string; email: string };
}

/** Link a professor's existing Google account to their game character. */
export async function assignHuntPublisher(
  _previous: HuntAssignmentState,
  formData: FormData,
): Promise<HuntAssignmentState> {
  const professor_id = String(formData.get("professor_id") ?? "").trim();
  const email = String(formData.get("email") ?? "").trim().toLowerCase();
  const values = { professor_id, email };
  if (!professor_id || !email.includes("@")) {
    return { error: "Selecciona el profesor e introduce un correo válido.", values };
  }

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "La sesión ha caducado. Vuelve a entrar.", values };

  const profile = await supabase.from("profiles").select("id").eq("email", email).maybeSingle();
  if (profile.error) return { error: profile.error.message, values };
  if (!profile.data) {
    return { error: "Esa cuenta todavía no ha entrado en Profesor GO. Pídele que inicie sesión primero.", values };
  }

  const result = await supabase
    .from("hunt_publishers")
    .upsert({ professor_id, user_id: profile.data.id }, { onConflict: "professor_id" })
    .select("professor_id");
  if (result.error || !result.data?.length) {
    return { error: result.error?.message ?? "No se pudo vincular la cuenta.", values };
  }
  revalidatePath("/hunt");
  return { success: `Cuenta ${email} vinculada al profesor.` };
}

export async function removeHuntPublisher(professorId: string): Promise<void> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("La sesión ha caducado.");
  const result = await supabase
    .from("hunt_publishers")
    .delete()
    .eq("professor_id", professorId)
    .select("professor_id");
  if (result.error || !result.data?.length) {
    throw new Error(result.error?.message ?? "No se encontró la asignación.");
  }
  revalidatePath("/hunt");
}
