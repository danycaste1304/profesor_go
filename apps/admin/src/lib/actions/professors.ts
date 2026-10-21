"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { validateProfessorInput } from "@/lib/game";
import { createClient } from "@/lib/supabase/server";
import { interpretWrite } from "@/lib/writes";
import type { ProfessorFormState } from "@/lib/types";

function revalidateProfessorPages(id?: string | null) {
  revalidatePath("/professors");
  revalidatePath("/nfc");
  revalidatePath("/dashboard");
  if (id) revalidatePath(`/professors/${id}`);
}

/** Creates (id = null) or updates a professor from the form data. Redirects on success. */
export async function saveProfessor(
  id: string | null,
  _prev: ProfessorFormState,
  formData: FormData,
): Promise<ProfessorFormState> {
  const result = validateProfessorInput({
    name: formData.get("name"),
    display_name: formData.get("display_name"),
    description: formData.get("description"),
    rarity: formData.get("rarity"),
    base_capture_rate: formData.get("base_capture_rate"),
    sprite_url: formData.get("sprite_url"),
    active: formData.get("active"),
  });

  if (!result.ok) {
    return { errors: result.errors, message: "Revisa los campos marcados." };
  }

  const supabase = await createClient();
  // `.select("id")` is what makes a no-op detectable: without it PostgREST answers
  // 204 with no error when the UPDATE matches zero rows (deleted row, wrong id, RLS).
  const written = id
    ? interpretWrite(
        await supabase
          .from("professors")
          .update({ ...result.value, updated_at: new Date().toISOString() })
          .eq("id", id)
          .select("id"),
        "guardar",
        "el profesor",
      )
    : interpretWrite(await supabase.from("professors").insert(result.value).select("id"), "crear", "el profesor");

  if (!written.ok) {
    return { errors: {}, message: written.message };
  }

  revalidateProfessorPages(id);
  redirect("/professors");
}

/** Toggles `professors.active`. Bound from the list page as a form action. */
export async function setProfessorActive(id: string, active: boolean): Promise<void> {
  const supabase = await createClient();
  const written = interpretWrite(
    await supabase
      .from("professors")
      .update({ active, updated_at: new Date().toISOString() })
      .eq("id", id)
      .select("id"),
    "actualizar",
    "el profesor",
  );
  if (!written.ok) {
    throw new Error(written.message);
  }
  revalidateProfessorPages(id);
}
