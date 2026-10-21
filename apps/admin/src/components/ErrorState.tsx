"use client";

import Link from "next/link";
import { Button, buttonClasses } from "@/components/ui";

/**
 * Shared presentation for the route error boundaries (`error.tsx`). The retry
 * button calls the `reset()` Next.js hands to the boundary, which re-renders the
 * failed segment (enough for a transient failure; an expired session ends up back
 * on /login through the middleware).
 */
export function ErrorState({
  title = "Algo ha salido mal",
  description = "No hemos podido completar la acción. Vuelve a intentarlo; si el problema continúa, cierra sesión y vuelve a entrar.",
  detail,
  digest,
  onRetry,
}: {
  title?: string;
  description?: string;
  detail?: string;
  digest?: string;
  onRetry: () => void;
}) {
  return (
    <div className="mx-auto w-full max-w-xl rounded-lg border border-slate-200 bg-white p-6 shadow-sm">
      <h1 className="text-xl font-bold tracking-tight text-slate-900">{title}</h1>
      <p className="mt-2 text-sm text-slate-600">{description}</p>
      {detail ? (
        <p className="mt-3 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800" role="alert">
          {detail}
        </p>
      ) : null}
      <div className="mt-5 flex flex-wrap gap-3">
        <Button type="button" onClick={onRetry}>
          Reintentar
        </Button>
        <Link href="/dashboard" className={buttonClasses("secondary")}>
          Volver al panel
        </Link>
      </div>
      {digest ? <p className="mt-4 text-xs text-slate-400">Código de error: {digest}</p> : null}
    </div>
  );
}
