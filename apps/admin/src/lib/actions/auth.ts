"use server";

import { redirect } from "next/navigation";
import { NOT_ADMIN_MESSAGE } from "@/lib/constants";
import { createClient } from "@/lib/supabase/server";
import type { LoginState } from "@/lib/types";

/** Email + password sign-in; only `profiles.role = 'admin'` accounts may continue. */
export async function signIn(_prev: LoginState, formData: FormData): Promise<LoginState> {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");

  if (!email || !password) {
    return { email, error: "Introduce tu correo y tu contraseña." };
  }

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error || !data.user) {
    return { email, error: "Credenciales incorrectas." };
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", data.user.id)
    .maybeSingle();

  if (profile?.role !== "admin") {
    await supabase.auth.signOut();
    return { email, error: NOT_ADMIN_MESSAGE };
  }

  redirect("/dashboard");
}

export async function signOut(): Promise<void> {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
