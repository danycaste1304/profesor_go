import type { Metadata } from "next";
import { HuntAssignmentForm } from "@/components/HuntAssignmentForm";
import { PageHeader } from "@/components/PageHeader";
import { SubmitButton } from "@/components/SubmitButton";
import { Alert, Card, EmptyRow, Table, TBody, THead, Td, Th, Tr } from "@/components/ui";
import { removeHuntPublisher } from "@/lib/actions/hunt";
import { createClient } from "@/lib/supabase/server";
import type { ProfessorOption } from "@/lib/types";

export const metadata: Metadata = { title: "Búsqueda en el campus" };

interface AssignmentRow {
  professor_id: string;
  professor: { display_name: string } | null;
  publisher: { email: string } | null;
}

interface SessionRow {
  id: string;
  started_at: string;
  ends_at: string;
  stopped_at: string | null;
  located_at: string | null;
  professor: { display_name: string } | null;
}

interface CheckinRow {
  session_id: string;
  checked_in_at: string;
  player: { email: string; display_name: string | null } | null;
  session: { professor: { display_name: string } | null } | null;
}

const formatDate = (value: string) => new Intl.DateTimeFormat("es-EC", {
  dateStyle: "short",
  timeStyle: "short",
  timeZone: "America/Guayaquil",
}).format(new Date(value));

export default async function HuntPage() {
  const supabase = await createClient();
  const [professorsResult, assignmentsResult, sessionsResult, checkinsResult] = await Promise.all([
    supabase.from("professors").select("id, name, display_name, active").eq("active", true).order("display_name"),
    supabase.from("hunt_publishers").select("professor_id, professor:professors(display_name), publisher:profiles(email)").order("created_at"),
    supabase.from("hunt_sessions").select("id, started_at, ends_at, stopped_at, located_at, professor:professors(display_name)").order("started_at", { ascending: false }).limit(20),
    supabase.from("hunt_checkins").select("session_id, checked_in_at, player:profiles(email, display_name), session:hunt_sessions(professor:professors(display_name))").order("checked_in_at", { ascending: false }).limit(200),
  ]);

  const loadError = professorsResult.error ?? assignmentsResult.error ?? sessionsResult.error ?? checkinsResult.error;
  const professors = (professorsResult.data ?? []) as ProfessorOption[];
  const assignments = (assignmentsResult.data ?? []) as unknown as AssignmentRow[];
  const sessions = (sessionsResult.data ?? []) as unknown as SessionRow[];
  const checkins = (checkinsResult.data ?? []) as unknown as CheckinRow[];
  const now = Date.now();

  return (
    <>
      <PageHeader
        title="Búsqueda en el campus"
        description="Vincula la cuenta del profesor y revisa quién tocó su tarjeta durante los 30 minutos."
        actions={<a href="/hunt/export" className="focus-ring rounded-xl bg-[#ffd447] px-4 py-2.5 text-sm font-bold text-[#172443]">Descargar CSV</a>}
      />
      <Alert tone="info">Para el punto extra, el profesor debe llevar la única tarjeta NFC activa de su personaje durante la búsqueda. Desactiva las demás en Tarjetas NFC antes de iniciar.</Alert>
      {loadError ? <Alert tone="error">No se pudieron cargar los datos: {loadError.message}</Alert> : (
        <div className="space-y-6">
          <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_21rem]">
            <Card title="Cuentas vinculadas" description="Solo estas cuentas pueden iniciar la búsqueda desde la app.">
              <Table>
                <THead><Tr><Th>Profesor</Th><Th>Cuenta</Th><Th className="text-right">Acción</Th></Tr></THead>
                <TBody>
                  {assignments.length === 0 ? <EmptyRow colSpan={3}>Aún no hay cuentas vinculadas.</EmptyRow> : assignments.map((item) => (
                    <Tr key={item.professor_id}>
                      <Td>{item.professor?.display_name ?? "Profesor"}</Td>
                      <Td>{item.publisher?.email ?? "Sin correo"}</Td>
                      <Td className="text-right">
                        <form action={removeHuntPublisher.bind(null, item.professor_id)}>
                          <SubmitButton variant="ghost" size="sm">Quitar</SubmitButton>
                        </form>
                      </Td>
                    </Tr>
                  ))}
                </TBody>
              </Table>
            </Card>
            <HuntAssignmentForm professors={professors} />
          </div>
          <Card title="Sesiones recientes" description="Cada sesión dura como máximo 30 minutos desde que el profesor pulsa Iniciar.">
            <Table>
              <THead><Tr><Th>Profesor</Th><Th>Inicio</Th><Th>Fin</Th><Th>Estado</Th><Th>Último GPS</Th></Tr></THead>
              <TBody>
                {sessions.length === 0 ? <EmptyRow colSpan={5}>Todavía no hay búsquedas.</EmptyRow> : sessions.map((session) => (
                  <Tr key={session.id}>
                    <Td>{session.professor?.display_name ?? "Profesor"}</Td>
                    <Td>{formatDate(session.started_at)}</Td>
                    <Td>{formatDate(session.ends_at)}</Td>
                    <Td>{session.stopped_at ? "Detenida" : new Date(session.ends_at).getTime() > now ? "Activa" : "Terminada"}</Td>
                    <Td>{session.located_at ? formatDate(session.located_at) : "Sin señal"}</Td>
                  </Tr>
                ))}
              </TBody>
            </Table>
          </Card>
          <Card title="Alumnos que encontraron al profesor" description="El toque NFC queda registrado una vez por alumno y sesión; el minijuego no afecta esta lista.">
            <Table>
              <THead><Tr><Th>Alumno</Th><Th>Correo</Th><Th>Profesor</Th><Th>Hora</Th></Tr></THead>
              <TBody>
                {checkins.length === 0 ? <EmptyRow colSpan={4}>Aún no hay hallazgos.</EmptyRow> : checkins.map((item) => (
                  <Tr key={`${item.session_id}-${item.player?.email ?? item.checked_in_at}`}>
                    <Td>{item.player?.display_name ?? "Alumno"}</Td>
                    <Td>{item.player?.email ?? ""}</Td>
                    <Td>{item.session?.professor?.display_name ?? "Profesor"}</Td>
                    <Td>{formatDate(item.checked_in_at)}</Td>
                  </Tr>
                ))}
              </TBody>
            </Table>
          </Card>
        </div>
      )}
    </>
  );
}
