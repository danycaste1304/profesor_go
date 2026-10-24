"use client";

import { useActionState } from "react";
import { SubmitButton } from "@/components/SubmitButton";
import { Alert, Card, Input, Select } from "@/components/ui";
import { registerNfcTag } from "@/lib/actions/nfc";
import type { NfcFormState, ProfessorOption } from "@/lib/types";

export function NfcForm({ professors }: { professors: ProfessorOption[] }) {
  const [state, formAction] = useActionState<NfcFormState, FormData>(registerNfcTag, {});

  const options = professors.map((professor) => ({
    value: professor.id,
    label: professor.active ? professor.display_name : `${professor.display_name} (inactivo)`,
  }));

  return (
    <Card title="Registrar tag" description="Si el identificador ya existe, se actualiza su asociación.">
      {/* Uncontrolled fields: React resets them after the action; on error the
          submitted values come back in `state.values` as new defaults. */}
      <form action={formAction} className="space-y-4">
        {state.error ? <Alert tone="error">{state.error}</Alert> : null}
        {state.success ? <Alert tone="success">{state.success}</Alert> : null}
        <Input
          label="Identificador del tag"
          name="tag_identifier"
          required
          maxLength={128}
          autoComplete="off"
          spellCheck={false}
          placeholder="ESTIMOTE:00A3… o UID NFC"
          defaultValue={state.values?.tag_identifier ?? ""}
          hint="Copia el identificador que muestra la app con una cuenta admin (hasta 128 caracteres)."
        />
        <Select
          label="Profesor"
          name="professor_id"
          options={options}
          placeholder="Sin profesor"
          defaultValue={state.values?.professor_id ?? ""}
        />
        <label className="flex items-center gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            name="active"
            defaultChecked={state.values?.active ?? true}
            className="h-4 w-4 rounded border-[#b6cbd8] text-[#087c9c] focus:ring-cyan-500"
          />
          Tag activo
        </label>
        <SubmitButton className="w-full">Guardar tag</SubmitButton>
      </form>
    </Card>
  );
}
