"use client";

import { useEffect } from "react";
import { ErrorState } from "@/components/ErrorState";

/**
 * Error boundary for the authenticated pages: it renders inside the sidebar
 * layout, so a failed toggle or save keeps the admin where they were instead of
 * dropping them on the default Next.js error page.
 */
export default function AppSectionError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("[admin] error no controlado:", error);
  }, [error]);

  // Server action errors are masked in production (only the digest survives), so the
  // message is shown when there is a real one, not the generic React placeholder.
  const detail = error.message && !error.message.startsWith("An error occurred in the Server") ? error.message : undefined;

  return (
    <ErrorState
      title="No se pudo completar la operación"
      description="Puede que tu sesión haya caducado o que el registro ya no exista. Vuelve a intentarlo; si el problema continúa, cierra sesión y vuelve a entrar."
      detail={detail}
      digest={error.digest}
      onRetry={reset}
    />
  );
}
