import type { Metadata } from "next";
import Link from "next/link";
import { PageHeader } from "@/components/PageHeader";
import { Alert, buttonClasses } from "@/components/ui";
import { normalizeAdminStats } from "@/lib/game";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = { title: "Dashboard" };

const numberFormat = new Intl.NumberFormat("es-ES");

function StatTile({ label, value, marker, note }: { label: string; value: number; marker: string; note: string }) {
  return (
    <div className="relative overflow-hidden rounded-2xl border border-[#dfe5ef] bg-white p-5 shadow-[0_10px_35px_-25px_#14203b66]">
      <div className="mb-5 flex items-start justify-between gap-3">
        <dt className="text-sm font-semibold text-[#66748f]">{label}</dt>
        <span aria-hidden="true" className="grid h-8 w-8 place-items-center rounded-lg bg-[#ecf8fa] text-sm font-black text-[#148999]">{marker}</span>
      </div>
      <dd className="text-4xl font-black tracking-tight text-[#172443] tabular-nums">{numberFormat.format(value)}</dd>
      <p className="mt-1 text-xs text-[#8895ab]">{note}</p>
    </div>
  );
}

export default async function DashboardPage() {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_stats");
  const stats = normalizeAdminStats(data);

  const tiles = [
    { label: "Jugadores", value: stats.total_players, marker: "01", note: "Cuentas registradas" },
    { label: "Capturas", value: stats.total_captures, marker: "02", note: "Encuentros ganados" },
    { label: "Profesores activos", value: stats.active_professors, marker: "03", note: "Disponibles en el juego" },
    { label: "Colecciones completas", value: stats.completed_collections, marker: "04", note: "Jugadores que completaron el reto" },
  ];

  return (
    <>
      <PageHeader title="Resumen" description="Toda la actividad del juego en un solo lugar." />
      <section className="relative mb-6 overflow-hidden rounded-[22px] border border-[#101b38] bg-[#172443] p-6 text-white shadow-[0_14px_40px_-25px_#0c1635] sm:p-8">
        <div aria-hidden="true" className="pointer-events-none absolute -right-12 -top-20 h-64 w-64 rounded-full border-[36px] border-[#2e476c] opacity-50" />
        <div aria-hidden="true" className="pointer-events-none absolute bottom-4 right-24 hidden h-20 w-20 rotate-12 border-[12px] border-[#ffd447] opacity-80 md:block" />
        <div className="relative max-w-xl">
          <span className="inline-flex rounded-full border border-[#68d5de]/40 bg-[#68d5de]/10 px-3 py-1 text-[10px] font-black uppercase tracking-[0.18em] text-[#92f1f4]">Panel de la feria</span>
          <h2 className="mt-4 text-2xl font-black leading-tight tracking-tight sm:text-3xl">Prepara la aventura.<br /><span className="text-[#ffd447]">Sigue cada captura.</span></h2>
          <p className="mt-3 text-sm leading-relaxed text-[#c6d3eb]">Gestiona el catálogo de profesores y sus tarjetas NFC. Las estadísticas se actualizan con los datos del juego.</p>
          <div className="mt-6 flex flex-wrap gap-3">
            <Link href="/professors/new" className="focus-ring inline-flex h-11 items-center rounded-xl bg-[#ffd447] px-4 text-sm font-bold text-[#172443] shadow-[0_4px_0_#bd982a] transition hover:bg-[#ffe17a]">Añadir profesor <span aria-hidden="true" className="ml-2">↗</span></Link>
            <Link href="/nfc" className="focus-ring inline-flex h-11 items-center rounded-xl border border-white/25 px-4 text-sm font-semibold text-white transition hover:bg-white/10">Administrar NFC <span aria-hidden="true" className="ml-2">→</span></Link>
          </div>
        </div>
      </section>
      {error ? (
        <div className="mb-6">
          <Alert tone="error">No se pudieron cargar las estadísticas: {error.message}</Alert>
        </div>
      ) : (
        <dl className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {tiles.map((tile) => <StatTile key={tile.label} {...tile} />)}
        </dl>
      )}
      <div className="mt-7 grid gap-4 md:grid-cols-2">
        <section className="rounded-2xl border border-[#dfe5ef] bg-white p-5 sm:p-6">
          <div className="mb-4 flex h-10 w-10 items-center justify-center rounded-xl bg-[#fff5cc] text-xl" aria-hidden="true">✦</div>
          <h2 className="text-lg font-black text-[#172443]">Catálogo de profesores</h2>
          <p className="mt-1 text-sm leading-relaxed text-[#66748f]">Revisa rareza, probabilidad de captura, sprite y disponibilidad de cada profesor.</p>
          <Link href="/professors" className={buttonClasses("secondary", "sm", "mt-5")}>Ver profesores <span aria-hidden="true">→</span></Link>
        </section>
        <section className="rounded-2xl border border-[#dfe5ef] bg-white p-5 sm:p-6">
          <div className="mb-4 flex h-10 w-10 items-center justify-center rounded-xl bg-[#def6f8] text-xl" aria-hidden="true">⌁</div>
          <h2 className="text-lg font-black text-[#172443]">Tarjetas NFC</h2>
          <p className="mt-1 text-sm leading-relaxed text-[#66748f]">Asocia los identificadores físicos y comprueba cuáles están activos para la feria.</p>
          <Link href="/nfc" className={buttonClasses("secondary", "sm", "mt-5")}>Ver tarjetas <span aria-hidden="true">→</span></Link>
        </section>
      </div>
    </>
  );
}
