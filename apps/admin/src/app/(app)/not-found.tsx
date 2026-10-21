import Link from "next/link";
import { PageHeader } from "@/components/PageHeader";
import { buttonClasses } from "@/components/ui";

export default function AppNotFound() {
  return (
    <>
      <PageHeader title="No encontrado" description="El recurso que buscas no existe o fue eliminado." />
      <Link href="/dashboard" className={buttonClasses("secondary")}>
        Volver al dashboard
      </Link>
    </>
  );
}
