"use client";

import { useActionState } from "react";
import { SubmitButton } from "@/components/SubmitButton";
import { Alert, Input } from "@/components/ui";
import { signIn } from "@/lib/actions/auth";
import type { LoginState } from "@/lib/types";

export function LoginForm({ initialError }: { initialError?: string }) {
  const [state, formAction] = useActionState<LoginState, FormData>(signIn, { error: initialError });

  return (
    <form action={formAction} className="space-y-4">
      {state.error ? <Alert tone="error">{state.error}</Alert> : null}
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
