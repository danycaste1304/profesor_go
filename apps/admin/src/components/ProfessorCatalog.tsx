"use client";

import Link from "next/link";
import { useState } from "react";
import { SubmitButton } from "@/components/SubmitButton";
import { ActiveBadge, RarityBadge } from "@/components/badges";
import { EmptyRow, TBody, THead, Table, Td, Th, Tr, buttonClasses, inputClasses } from "@/components/ui";
import { setProfessorActive } from "@/lib/actions/professors";
import { formatRate, RARITIES, RARITY_LABELS } from "@/lib/game";
import type { Professor } from "@/lib/types";

function SpriteThumb({ professor }: { professor: Professor }) {
  if (professor.sprite_url) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img src={professor.sprite_url} alt="" width={44} height={44} className="h-11 w-11 shrink-0 rounded-xl border border-[#dfe5ef] bg-[#f6f8fc] object-contain" />
    );
  }
  return <div aria-hidden="true" className="grid h-11 w-11 shrink-0 place-items-center rounded-xl border border-dashed border-[#bbc8da] bg-[#f5f8fc] text-xs font-black text-[#7b8ba5]">{professor.display_name.replace(/^Prof\.?\s*/i, "").slice(0, 2).toUpperCase()}</div>;
}

export function ProfessorCatalog({ professors }: { professors: Professor[] }) {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const [rarity, setRarity] = useState("all");
  const query = search.trim().toLocaleLowerCase("es");
  const filtered = professors.filter((professor) =>
    (!query || `${professor.name} ${professor.display_name}`.toLocaleLowerCase("es").includes(query)) &&
    (status === "all" || professor.active === (status === "active")) &&
    (rarity === "all" || professor.rarity === rarity),
  );

  return (
    <section aria-label="Catálogo de profesores">
      <div className="mb-4 flex flex-col gap-3 rounded-2xl border border-[#dfe5ef] bg-white p-4 shadow-sm sm:flex-row sm:items-end">
        <div className="min-w-0 flex-1">
          <label htmlFor="professor-search" className="mb-1 block text-xs font-bold text-[#52617c]">Buscar profesor</label>
          <input id="professor-search" type="search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Nombre o nombre visible" className={inputClasses} />
        </div>
        <div className="sm:w-36">
          <label htmlFor="professor-status" className="mb-1 block text-xs font-bold text-[#52617c]">Estado</label>
          <select id="professor-status" value={status} onChange={(event) => setStatus(event.target.value)} className={inputClasses}>
            <option value="all">Todos</option><option value="active">Activos</option><option value="inactive">Inactivos</option>
          </select>
        </div>
        <div className="sm:w-40">
          <label htmlFor="professor-rarity" className="mb-1 block text-xs font-bold text-[#52617c]">Rareza</label>
          <select id="professor-rarity" value={rarity} onChange={(event) => setRarity(event.target.value)} className={inputClasses}>
            <option value="all">Todas</option>{RARITIES.map((item) => <option key={item} value={item}>{RARITY_LABELS[item]}</option>)}
          </select>
        </div>
      </div>
      <p className="mb-3 text-xs font-semibold text-[#66748f]" aria-live="polite">Mostrando {filtered.length} de {professors.length} profesores</p>
      <Table>
        <THead><Tr><Th>Profesor</Th><Th>Rareza</Th><Th>Estado</Th><Th>Probabilidad</Th><Th className="text-right">Acciones</Th></Tr></THead>
        <TBody>
          {filtered.length === 0 ? <EmptyRow colSpan={5}>{professors.length === 0 ? "Todavía no hay profesores. Crea el primero." : "No hay profesores que coincidan con los filtros."}</EmptyRow> : filtered.map((professor) => (
            <Tr key={professor.id}>
              <Td><div className="flex items-center gap-3"><SpriteThumb professor={professor} /><div className="min-w-0"><div className="font-bold text-[#172443]">{professor.display_name}</div><div className="truncate text-xs text-[#8290a7]">{professor.name}</div></div></div></Td>
              <Td><RarityBadge rarity={professor.rarity} /></Td>
              <Td><ActiveBadge active={professor.active} /></Td>
              <Td className="font-semibold tabular-nums">{formatRate(Number(professor.base_capture_rate))}</Td>
              <Td className="text-right"><div className="flex justify-end gap-2"><Link href={`/professors/${professor.id}`} className={buttonClasses("secondary", "sm")}>Editar</Link><form action={setProfessorActive.bind(null, professor.id, !professor.active)}><SubmitButton variant={professor.active ? "ghost" : "secondary"} size="sm" pendingText="…">{professor.active ? "Desactivar" : "Activar"}</SubmitButton></form></div></Td>
            </Tr>
          ))}
        </TBody>
      </Table>
    </section>
  );
}
