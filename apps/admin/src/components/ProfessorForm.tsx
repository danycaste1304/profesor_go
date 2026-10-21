"use client";

import Link from "next/link";
import { useActionState, useState, type ChangeEvent } from "react";
import { SubmitButton } from "@/components/SubmitButton";
import { Alert, Button, Card, Input, Select, Textarea, buttonClasses } from "@/components/ui";
import { saveProfessor } from "@/lib/actions/professors";
import { MAX_SPRITE_BYTES, SPRITES_BUCKET } from "@/lib/constants";
import {
  DEFAULT_CAPTURE_RATE,
  MAX_DESCRIPTION_LENGTH,
  MAX_NAME_LENGTH,
  RARITIES,
  RARITY_LABELS,
  SPRITE_ACCEPT_ATTRIBUTE,
  SPRITE_FORMATS_LABEL,
  formatMaxBytes,
  formatRate,
  validateSpriteFile,
  type Rarity,
} from "@/lib/game";
import { createClient } from "@/lib/supabase/client";
import type { Professor, ProfessorFormState } from "@/lib/types";

interface FormValues {
  name: string;
  display_name: string;
  description: string;
  rarity: Rarity;
  base_capture_rate: string;
  sprite_url: string;
  active: boolean;
}

type UploadState = { status: "idle" | "uploading" } | { status: "error"; message: string };

const rarityOptions = RARITIES.map((rarity) => ({
  value: rarity,
  label: `${RARITY_LABELS[rarity]} (${formatRate(DEFAULT_CAPTURE_RATE[rarity])})`,
}));

function initialValues(professor: Professor | null): FormValues {
  if (!professor) {
    return {
      name: "",
      display_name: "",
      description: "",
      rarity: "COMMON",
      base_capture_rate: String(DEFAULT_CAPTURE_RATE.COMMON),
      sprite_url: "",
      active: true,
    };
  }
  return {
    name: professor.name,
    display_name: professor.display_name,
    description: professor.description ?? "",
    rarity: professor.rarity,
    base_capture_rate: String(professor.base_capture_rate),
    sprite_url: professor.sprite_url ?? "",
    active: professor.active,
  };
}

function randomId(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) return crypto.randomUUID();
  return `${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

export function ProfessorForm({ professor }: { professor: Professor | null }) {
  const [values, setValues] = useState<FormValues>(() => initialValues(professor));
  // The rate follows the rarity default until the admin types a custom value.
  const [rateOverridden, setRateOverridden] = useState<boolean>(
    () => professor !== null && Number(professor.base_capture_rate) !== DEFAULT_CAPTURE_RATE[professor.rarity],
  );
  const [upload, setUpload] = useState<UploadState>({ status: "idle" });
  const [state, formAction] = useActionState<ProfessorFormState, FormData>(
    saveProfessor.bind(null, professor?.id ?? null),
    { errors: {} },
  );

  const update = <K extends keyof FormValues>(key: K, value: FormValues[K]) =>
    setValues((current) => ({ ...current, [key]: value }));

  function handleRarityChange(event: ChangeEvent<HTMLSelectElement>) {
    const rarity = event.target.value as Rarity;
    setValues((current) => ({
      ...current,
      rarity,
      base_capture_rate: rateOverridden ? current.base_capture_rate : String(DEFAULT_CAPTURE_RATE[rarity]),
    }));
  }

  function handleRateChange(event: ChangeEvent<HTMLInputElement>) {
    setRateOverridden(true);
    update("base_capture_rate", event.target.value);
  }

  function resetRateToDefault() {
    setRateOverridden(false);
    update("base_capture_rate", String(DEFAULT_CAPTURE_RATE[values.rarity]));
  }

  async function handleSpriteChange(event: ChangeEvent<HTMLInputElement>) {
    const input = event.target;
    const file = input.files?.[0];
    if (!file) return;

    // Raster allowlist only: the bucket is public, so an SVG would be a stored-XSS
    // vector. `accept` is just a hint in the file dialog, this is the real check.
    const check = validateSpriteFile({ name: file.name, type: file.type, size: file.size });
    if (!check.ok) {
      setUpload({ status: "error", message: check.message });
      input.value = "";
      return;
    }

    setUpload({ status: "uploading" });
    try {
      const supabase = createClient();
      const path = `${randomId()}.${check.extension}`;
      const { error } = await supabase.storage
        .from(SPRITES_BUCKET)
        // Explicit contentType from the allowlist, never the raw browser value.
        .upload(path, file, { contentType: check.contentType, cacheControl: "3600", upsert: false });
      if (error) throw new Error(error.message);
      const { data } = supabase.storage.from(SPRITES_BUCKET).getPublicUrl(path);
      update("sprite_url", data.publicUrl);
      setUpload({ status: "idle" });
    } catch (error) {
      setUpload({
        status: "error",
        message: error instanceof Error ? `No se pudo subir el sprite: ${error.message}` : "No se pudo subir el sprite.",
      });
    } finally {
      input.value = "";
    }
  }

  const defaultRate = DEFAULT_CAPTURE_RATE[values.rarity];
  const errors = state.errors;

  return (
    <form action={formAction} className="space-y-6">
      {state.message ? <Alert tone="error">{state.message}</Alert> : null}

      <Card title="Datos básicos">
        <div className="grid gap-4 sm:grid-cols-2">
          <Input
            label="Nombre"
            name="name"
            required
            maxLength={MAX_NAME_LENGTH}
            placeholder="Ada Lovelace"
            value={values.name}
            onChange={(event) => update("name", event.target.value)}
            error={errors.name}
          />
          <Input
            label="Nombre visible"
            name="display_name"
            required
            maxLength={MAX_NAME_LENGTH}
            placeholder="Prof. Ada"
            value={values.display_name}
            onChange={(event) => update("display_name", event.target.value)}
            error={errors.display_name}
            hint="Es el nombre que ven los jugadores."
          />
          <div className="sm:col-span-2">
            <Textarea
              label="Descripción"
              name="description"
              maxLength={MAX_DESCRIPTION_LENGTH}
              placeholder="Breve descripción que se muestra en la colección."
              value={values.description}
              onChange={(event) => update("description", event.target.value)}
              error={errors.description}
            />
          </div>
        </div>
      </Card>

      <Card title="Rareza y captura">
        <div className="grid gap-4 sm:grid-cols-2">
          <Select
            label="Rareza"
            name="rarity"
            options={rarityOptions}
            value={values.rarity}
            onChange={handleRarityChange}
            error={errors.rarity}
          />
          <Input
            label="Probabilidad base de captura (0 a 1)"
            name="base_capture_rate"
            type="number"
            inputMode="decimal"
            // `any`, not a fixed step: rates are free numerics in [0,1] (CONTRACTS §2) and a
            // stepped input would refuse to submit an existing value like 0.255.
            step="any"
            min={0}
            max={1}
            required
            value={values.base_capture_rate}
            onChange={handleRateChange}
            error={errors.base_capture_rate}
            hint={
              <span className="flex flex-wrap items-center gap-2">
                <span>
                  Por defecto para {RARITY_LABELS[values.rarity]}: {defaultRate} ({formatRate(defaultRate)}).
                </span>
                {rateOverridden ? (
                  <button
                    type="button"
                    onClick={resetRateToDefault}
                    className="font-semibold text-[#087c9c] underline-offset-2 hover:underline"
                  >
                    Usar valor por defecto
                  </button>
                ) : null}
              </span>
            }
          />
        </div>
      </Card>

      <Card title="Sprite" description="Imagen del profesor. Se sube al bucket público «professor-sprites».">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-start">
          <div className="flex h-32 w-32 shrink-0 items-center justify-center overflow-hidden rounded-2xl border border-dashed border-[#b6cbd8] bg-[#edf7f8]">
            {values.sprite_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={values.sprite_url} alt="Vista previa del sprite" className="h-full w-full object-contain" />
            ) : (
              <span className="px-2 text-center text-xs text-slate-400">Sin sprite</span>
            )}
          </div>
          <div className="min-w-0 flex-1 space-y-3">
            <div className="space-y-1">
              <label htmlFor="sprite_file" className="block text-sm font-medium text-slate-700">
                Subir imagen
              </label>
              <input
                id="sprite_file"
                type="file"
                accept={SPRITE_ACCEPT_ATTRIBUTE}
                onChange={handleSpriteChange}
                disabled={upload.status === "uploading"}
                className="block w-full text-sm text-[#66748f] file:mr-3 file:rounded-lg file:border-0 file:bg-[#e4f6f8] file:px-3 file:py-2 file:text-sm file:font-semibold file:text-[#087c9c] hover:file:bg-[#d3f1f4]"
              />
              <p className="text-xs text-slate-500">
                {SPRITE_FORMATS_LABEL} de hasta {formatMaxBytes(MAX_SPRITE_BYTES)}. No se admiten archivos SVG.
              </p>
            </div>
            {upload.status === "uploading" ? (
              <p className="text-sm text-slate-600" aria-live="polite">
                Subiendo sprite…
              </p>
            ) : null}
            {upload.status === "error" ? <Alert tone="error">{upload.message}</Alert> : null}
            {errors.sprite_url ? <Alert tone="error">{errors.sprite_url}</Alert> : null}
            {values.sprite_url ? (
              <div className="flex flex-wrap items-center gap-3">
                <a
                  href={values.sprite_url}
                  target="_blank"
                  rel="noreferrer"
                  className="max-w-full truncate text-xs text-[#087c9c] hover:underline"
                >
                  {values.sprite_url}
                </a>
                <Button type="button" variant="ghost" size="sm" onClick={() => update("sprite_url", "")}>
                  Quitar sprite
                </Button>
              </div>
            ) : null}
            <input type="hidden" name="sprite_url" value={values.sprite_url} />
          </div>
        </div>
      </Card>

      <Card title="Estado">
        <label className="flex items-center gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            name="active"
            checked={values.active}
            onChange={(event) => update("active", event.target.checked)}
            className="h-4 w-4 rounded border-[#b6cbd8] text-[#087c9c] focus:ring-cyan-500"
          />
          Profesor activo (visible y capturable en el juego)
        </label>
      </Card>

      <div className="flex flex-wrap gap-3">
        <SubmitButton disabled={upload.status === "uploading"}>
          {professor ? "Guardar cambios" : "Crear profesor"}
        </SubmitButton>
        <Link href="/professors" className={buttonClasses("secondary")}>
          Cancelar
        </Link>
      </div>
    </form>
  );
}
