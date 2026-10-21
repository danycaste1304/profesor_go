"use client";

import { useState } from "react";
import { SubmitButton } from "@/components/SubmitButton";
import { ActiveBadge } from "@/components/badges";
import { EmptyRow, TBody, THead, Table, Td, Th, Tr, inputClasses } from "@/components/ui";
import { setNfcTagActive } from "@/lib/actions/nfc";
import type { NfcTagRow } from "@/lib/types";

export function NfcCatalog({ tags }: { tags: NfcTagRow[] }) {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const query = search.trim().toLocaleLowerCase("es");
  const filtered = tags.filter((tag) =>
    (!query || `${tag.tag_identifier} ${tag.professor?.display_name ?? ""} ${tag.professor?.name ?? ""}`.toLocaleLowerCase("es").includes(query)) &&
    (status === "all" || tag.active === (status === "active")),
  );

  return (
    <section aria-label="Tarjetas NFC registradas">
      <div className="mb-4 flex flex-col gap-3 rounded-2xl border border-[#dfe5ef] bg-white p-4 shadow-sm sm:flex-row sm:items-end">
        <div className="min-w-0 flex-1"><label htmlFor="nfc-search" className="mb-1 block text-xs font-bold text-[#52617c]">Buscar tarjeta</label><input id="nfc-search" type="search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Identificador o profesor" className={inputClasses} /></div>
        <div className="sm:w-32"><label htmlFor="nfc-status" className="mb-1 block text-xs font-bold text-[#52617c]">Estado</label><select id="nfc-status" value={status} onChange={(event) => setStatus(event.target.value)} className={inputClasses}><option value="all">Todos</option><option value="active">Activos</option><option value="inactive">Inactivos</option></select></div>
      </div>
      <p className="mb-3 text-xs font-semibold text-[#66748f]" aria-live="polite">Mostrando {filtered.length} de {tags.length} tarjetas</p>
      <Table>
        <THead><Tr><Th>Identificador</Th><Th>Profesor</Th><Th>Estado</Th><Th className="text-right">Acciones</Th></Tr></THead>
        <TBody>
          {filtered.length === 0 ? <EmptyRow colSpan={4}>{tags.length === 0 ? "Todavía no hay tarjetas registradas." : "No hay tarjetas que coincidan con los filtros."}</EmptyRow> : filtered.map((tag) => (
            <Tr key={tag.id}>
              <Td className="font-mono text-xs font-bold">{tag.tag_identifier}</Td>
              <Td>{tag.professor ? <div><div className="font-bold text-[#172443]">{tag.professor.display_name}</div><div className="text-xs text-[#8290a7]">{tag.professor.name}</div></div> : <span className="text-[#8290a7]">Sin profesor</span>}</Td>
              <Td><ActiveBadge active={tag.active} /></Td>
              <Td className="text-right"><form action={setNfcTagActive.bind(null, tag.id, !tag.active)} className="inline-block"><SubmitButton variant={tag.active ? "ghost" : "secondary"} size="sm" pendingText="…">{tag.active ? "Desactivar" : "Activar"}</SubmitButton></form></Td>
            </Tr>
          ))}
        </TBody>
      </Table>
    </section>
  );
}
