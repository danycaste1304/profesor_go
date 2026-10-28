import type { Metadata } from "next";
import { PageHeader } from "@/components/PageHeader";
import { QrCatalog } from "@/components/QrCatalog";
import { Alert } from "@/components/ui";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = { title: "Códigos QR" };

export default async function QrPage() {
  const supabase = await createClient();
  const [professors, codes] = await Promise.all([
    supabase.from("professors").select("id, display_name, active").order("display_name"),
    supabase.from("professor_qr_codes").select("professor_id, active, rotated_at"),
  ]);
  const error = professors.error ?? codes.error;
  return <>
    <PageHeader title="Códigos QR" description="Imprime un código distinto para cada profesor. Al reemplazarlo, el papel anterior deja de funcionar." />
    {error ? <Alert tone="error">No se pudieron cargar los QR: {error.message}</Alert> :
      <QrCatalog
        professors={(professors.data ?? []) as { id: string; display_name: string; active: boolean }[]}
        codes={(codes.data ?? []) as { professor_id: string; active: boolean; rotated_at: string }[]}
      />}
  </>;
}
