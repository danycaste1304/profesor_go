"use client";

import { useEffect } from "react";
import { ErrorState } from "@/components/ErrorState";

/**
 * Route error boundary for everything under the root layout (must be a Client
 * Component). Without it, a server action that throws — an expired session in the
 * middle of a toggle, for example — renders the default Next.js error page.
 */
export default function RootError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("[admin] error no controlado:", error);
  }, [error]);

  return (
    <main className="flex min-h-screen items-center justify-center p-4 sm:p-6">
      <ErrorState
        description="Se ha producido un error inesperado. Vuelve a intentarlo; si el problema continúa, cierra sesión y vuelve a entrar."
        digest={error.digest}
        onRetry={reset}
      />
    </main>
  );
}
