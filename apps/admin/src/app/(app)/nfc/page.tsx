import type { Metadata } from "next";
import { NfcCatalog } from "@/components/NfcCatalog";
import { NfcForm } from "@/components/NfcForm";
import { PageHeader } from "@/components/PageHeader";
import { Alert } from "@/components/ui";
import { createClient } from "@/lib/supabase/server";
import type { NfcTagRow, ProfessorOption } from "@/lib/types";

export const metadata: Metadata = { title: "Tarjetas NFC" };

export default async function NfcPage() {
  const supabase = await createClient();
  const [tagsResult, professorsResult] = await Promise.all([
    supabase.from("nfc_tags").select("id, tag_identifier, professor_id, active, created_at, professor:professors(id, name, display_name)").order("created_at", { ascending: true }),
    supabase.from("professors").select("id, name, display_name, active").order("display_name", { ascending: true }),
  ]);

  const tags = (tagsResult.data ?? []) as unknown as NfcTagRow[];
  const professors = (professorsResult.data ?? []) as ProfessorOption[];
  const loadError = tagsResult.error ?? professorsResult.error;

  return (
    <>
      <PageHeader title="Tarjetas NFC" description="Vincula cada tarjeta física de la feria con un profesor." />
      {loadError ? <Alert tone="error">No se pudieron cargar los datos: {loadError.message}</Alert> : (
        <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_21rem]">
          <div className="xl:order-2"><NfcForm professors={professors} /></div>
          <div className="min-w-0 xl:order-1"><NfcCatalog tags={tags} /></div>
        </div>
      )}
    </>
  );
}
