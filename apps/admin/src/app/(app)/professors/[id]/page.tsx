import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { PageHeader } from "@/components/PageHeader";
import { ProfessorForm } from "@/components/ProfessorForm";
import { createClient } from "@/lib/supabase/server";
import type { Professor } from "@/lib/types";

export const metadata: Metadata = { title: "Editar profesor" };

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export default async function EditProfessorPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!UUID_RE.test(id)) notFound();

  const supabase = await createClient();
  const { data } = await supabase.from("professors").select("*").eq("id", id).maybeSingle();
  if (!data) notFound();

  const professor = data as Professor;

  return (
    <>
      <PageHeader title={professor.display_name} description={`Editando a ${professor.name}.`} />
      <ProfessorForm professor={professor} />
    </>
  );
}
