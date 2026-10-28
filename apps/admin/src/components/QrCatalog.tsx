"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import QRCode from "qrcode";
import { rotateProfessorQr, setProfessorQrActive } from "@/lib/actions/qr";

interface Professor { id: string; display_name: string; active: boolean }
interface Code { professor_id: string; active: boolean; rotated_at: string }

export function QrCatalog({ professors, codes }: { professors: Professor[]; codes: Code[] }) {
  const router = useRouter();
  const [printing, setPrinting] = useState<{ name: string; url: string; image: string } | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [message, setMessage] = useState("");
  const byProfessor = new Map(codes.map((code) => [code.professor_id, code]));

  async function rotate(professor: Professor) {
    if (byProfessor.has(professor.id) &&
        !window.confirm(`Reemplazar el QR de ${professor.display_name}? El código impreso anterior dejará de funcionar.`)) return;
    setBusy(professor.id);
    setMessage("");
    try {
      const result = await rotateProfessorQr(professor.id);
      if (!result.url) { setMessage(result.error ?? "No se pudo crear el QR."); return; }
      const image = await QRCode.toDataURL(result.url, { errorCorrectionLevel: "M", margin: 2, width: 700 });
      setPrinting({ name: professor.display_name, url: result.url, image });
      setMessage("Imprime o guarda este QR ahora. El código no volverá a mostrarse.");
      router.refresh();
    } catch {
      setMessage("No se pudo preparar el QR para imprimir. Reemplázalo e inténtalo de nuevo.");
    } finally { setBusy(null); }
  }

  async function toggle(professor: Professor, active: boolean) {
    setBusy(professor.id);
    const result = await setProfessorQrActive(professor.id, active);
    setMessage(result.error ?? (active ? "QR activado." : "QR desactivado."));
    if (!result.error) router.refresh();
    setBusy(null);
  }

  return <div className="space-y-5">
    <p className="rounded-xl bg-amber-50 p-4 text-sm text-amber-950">Un QR impreso puede fotografiarse y compartirse. El profesor debe llevarlo consigo y el organizador puede desactivarlo desde aquí.</p>
    {message && <p role="status" className="rounded-xl bg-white p-3 text-sm">{message}</p>}
    <div className="grid gap-3 sm:grid-cols-2">
      {professors.map((professor) => {
        const code = byProfessor.get(professor.id);
        return <div key={professor.id} className="rounded-xl border bg-white p-4">
          <div className="font-bold">{professor.display_name}</div>
          <div className="mb-3 text-sm text-slate-600">{code ? (code.active ? "QR activo" : "QR desactivado") : "Sin QR"}</div>
          <div className="flex flex-wrap gap-2">
            <button type="button" disabled={busy === professor.id} onClick={() => rotate(professor)} className="rounded-lg bg-[#ffd447] px-3 py-2 text-sm font-bold text-[#172443] disabled:opacity-50">{code ? "Reemplazar e imprimir" : "Crear e imprimir"}</button>
            {code && <button type="button" disabled={busy === professor.id} onClick={() => toggle(professor, !code.active)} className="rounded-lg border px-3 py-2 text-sm disabled:opacity-50">{code.active ? "Desactivar" : "Activar"}</button>}
          </div>
        </div>;
      })}
    </div>
    {printing && <div className="qr-sheet rounded-xl border bg-white p-5 print:border-0 print:p-0">
      <h2 className="mb-3 text-xl font-bold">{printing.name}</h2>
      {/* A data URL never sends the printed code to a third-party QR service. */}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={printing.image} alt={`QR de ${printing.name}`} className="mx-auto h-72 w-72 print:h-[16cm] print:w-[16cm]" />
      <p className="mt-3 break-all text-center text-xs">{printing.url}</p>
      <button type="button" onClick={() => window.print()} className="mt-4 rounded-lg bg-[#ffd447] px-4 py-2 font-bold print:hidden">Imprimir QR</button>
    </div>}
  </div>;
}
