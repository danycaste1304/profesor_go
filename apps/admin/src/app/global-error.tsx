"use client";

/**
 * Last-resort boundary: it replaces the root layout when the layout itself fails,
 * so it renders its own <html>/<body> and cannot rely on the app stylesheet
 * (hence the inline styles).
 */
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <html lang="es">
      <body
        style={{
          margin: 0,
          minHeight: "100vh",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          padding: "1.5rem",
          backgroundColor: "#f8fafc",
          color: "#0f172a",
          fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, sans-serif",
        }}
      >
        <div style={{ maxWidth: "36rem", textAlign: "center" }}>
          <h1 style={{ fontSize: "1.25rem", fontWeight: 700, margin: 0 }}>Algo ha salido mal</h1>
          <p style={{ marginTop: "0.5rem", fontSize: "0.875rem", color: "#475569" }}>
            El panel no ha podido cargarse. Vuelve a intentarlo; si el problema continúa, cierra sesión y vuelve a
            entrar.
          </p>
          <button
            type="button"
            onClick={() => reset()}
            style={{
              marginTop: "1.25rem",
              height: "2.5rem",
              padding: "0 1rem",
              borderRadius: "0.375rem",
              border: "none",
              backgroundColor: "#4f46e5",
              color: "#ffffff",
              fontSize: "0.875rem",
              fontWeight: 500,
              cursor: "pointer",
            }}
          >
            Reintentar
          </button>
          {error.digest ? (
            <p style={{ marginTop: "1rem", fontSize: "0.75rem", color: "#94a3b8" }}>Código de error: {error.digest}</p>
          ) : null}
        </div>
      </body>
    </html>
  );
}
