import Link from "next/link";
import { buttonClasses } from "@/components/ui";

export default function NotFound() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-4 p-6 text-center">
      <h1 className="text-2xl font-bold">Página no encontrada</h1>
      <p className="text-slate-500">La página que buscas no existe.</p>
      <Link href="/dashboard" className={buttonClasses("secondary")}>
        Volver al panel
      </Link>
    </main>
  );
}
