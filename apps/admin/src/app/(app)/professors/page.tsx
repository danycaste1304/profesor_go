import type { Metadata } from "next";
import Link from "next/link";
import { PageHeader } from "@/components/PageHeader";
import { ProfessorCatalog } from "@/components/ProfessorCatalog";
import { Alert, buttonClasses } from "@/components/ui";
import { createClient } from "@/lib/supabase/server";
import type { Professor } from "@/lib/types";

export const metadata: Metadata = { title: "Profesores" };

export default async function ProfessorsPage() {
  const supabase = await createClient();
  const { data, error } = await supabase.from("professors").select("*").order("created_at", { ascending: true });
  const professors = (data ?? []) as Professor[];

  return (
    <>
      <PageHeader title="Profesores" description="Gestiona los personajes que los jugadores pueden capturar." actions={<Link href="/professors/new" className={buttonClasses("primary")}>+ Nuevo profesor</Link>} />
      {error ? <Alert tone="error">No se pudieron cargar los profesores: {error.message}</Alert> : <ProfessorCatalog professors={professors} />}
    </>
  );
}
