import type { Metadata } from "next";
import { PageHeader } from "@/components/PageHeader";
import { ProfessorForm } from "@/components/ProfessorForm";

export const metadata: Metadata = { title: "Nuevo profesor" };

export default function NewProfessorPage() {
  return (
    <>
      <PageHeader title="Nuevo profesor" description="Añade un profesor al catálogo." />
      <ProfessorForm professor={null} />
    </>
  );
}
