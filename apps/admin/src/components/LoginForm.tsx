"use client";

import { useActionState, useState } from "react";
import { SubmitButton } from "@/components/SubmitButton";
import { Alert, Input } from "@/components/ui";
import { signIn } from "@/lib/actions/auth";
import { createClient } from "@/lib/supabase/client";
import type { LoginState } from "@/lib/types";

export function LoginForm({ initialError }: { initialError?: string }) {
  const [state, formAction] = useActionState<LoginState, FormData>(signIn, { error: initialError });
  const [googleLoading, setGoogleLoading] = useState(false);
  const [googleError, setGoogleError] = useState<string | null>(null);

  async function signInWithGoogle() {
    setGoogleLoading(true);
    setGoogleError(null);
    try {
      const { error } = await createClient().auth.signInWithOAuth({
        provider: "google",
        options: { redirectTo: `${window.location.origin}/auth/callback` },
      });
      if (!error) return;
    } catch {
      // Show the same retry message for browser/network failures.
    }
    setGoogleError("No se pudo iniciar el acceso con Google. Inténtalo de nuevo.");
    setGoogleLoading(false);
  }

  return (
    <form action={formAction} className="space-y-4">
      {state.error ? <Alert tone="error">{state.error}</Alert> : null}
      {googleError ? <Alert tone="error">{googleError}</Alert> : null}
      <button
        type="button"
        onClick={signInWithGoogle}
        disabled={googleLoading}
        className="w-full rounded-xl bg-[#172443] px-4 py-3 font-bold text-white disabled:opacity-60"
      >
        {googleLoading ? "Abriendo Google…" : "Continuar con Google"}
      </button>
      <p className="text-center text-xs text-[#66748f]">O entra con tu cuenta de administrador existente</p>
      <Input
        label="Correo electrónico"
        name="email"
        type="email"
        autoComplete="email"
        required
        defaultValue={state.email ?? ""}
        placeholder="admin@profesorgo.local"
      />
      <Input
        label="Contraseña"
        name="password"
        type="password"
        autoComplete="current-password"
        required
        minLength={6}
      />
      <SubmitButton className="w-full" pendingText="Entrando…">
        Iniciar sesión
      </SubmitButton>
    </form>
  );
}
