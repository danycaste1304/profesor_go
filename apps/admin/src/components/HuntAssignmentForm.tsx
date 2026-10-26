"use client";

import { useActionState } from "react";
import { SubmitButton } from "@/components/SubmitButton";
import { Alert, Card, Input, Select } from "@/components/ui";
import { assignHuntPublisher, type HuntAssignmentState } from "@/lib/actions/hunt";
import type { ProfessorOption } from "@/lib/types";

export function HuntAssignmentForm({ professors }: { professors: ProfessorOption[] }) {
  const [state, action] = useActionState<HuntAssignmentState, FormData>(assignHuntPublisher, {});
  return (
    <Card title="Cuenta del profesor" description="El profesor debe entrar primero en la app con Google.">
      <form action={action} className="space-y-4">
        {state.error ? <Alert tone="error">{state.error}</Alert> : null}
        {state.success ? <Alert tone="success">{state.success}</Alert> : null}
        <Select
          label="Personaje"
          name="professor_id"
          options={professors.map((professor) => ({ value: professor.id, label: professor.display_name }))}
          placeholder="Selecciona un profesor"
          required
          defaultValue={state.values?.professor_id ?? ""}
        />
        <Input
          label="Gmail del profesor"
          name="email"
          type="email"
          required
          placeholder="profesor@gmail.com"
          defaultValue={state.values?.email ?? ""}
        />
        <SubmitButton className="w-full">Vincular cuenta</SubmitButton>
      </form>
    </Card>
  );
}
