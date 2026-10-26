import { createClient } from "@/lib/supabase/server";

interface ExportRow {
  session_id: string;
  checked_in_at: string;
  player: { email: string; display_name: string | null } | null;
  session: { professor: { display_name: string } | null } | null;
}

function csvCell(value: string | null | undefined): string {
  const raw = value ?? "";
  // Prevent spreadsheet formulas in user-controlled names and emails.
  const safe = /^[=+\-@\t\r]/.test(raw) ? `'${raw}` : raw;
  return `"${safe.replaceAll('"', '""')}"`;
}

export async function GET() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response("Inicia sesión.", { status: 401 });
  const profile = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle();
  if (profile.data?.role !== "admin") return new Response("Sin permiso.", { status: 403 });

  const rows: ExportRow[] = [];
  const pageSize = 500;
  for (let offset = 0; ; offset += pageSize) {
    const result = await supabase
      .from("hunt_checkins")
      .select("session_id, checked_in_at, player:profiles(email, display_name), session:hunt_sessions(professor:professors(display_name))")
      .order("checked_in_at", { ascending: true })
      .range(offset, offset + pageSize - 1);
    if (result.error) return new Response("No se pudo exportar la lista.", { status: 500 });
    const page = (result.data ?? []) as unknown as ExportRow[];
    rows.push(...page);
    if (page.length < pageSize) break;
  }

  const header = ["Sesion", "Profesor", "Alumno", "Correo", "Hora UTC"];
  const lines = [
    header.map(csvCell).join(","),
    ...rows.map((row) => [
      row.session_id,
      row.session?.professor?.display_name ?? "",
      row.player?.display_name ?? "",
      row.player?.email ?? "",
      row.checked_in_at,
    ].map(csvCell).join(",")),
  ];

  return new Response(`\uFEFF${lines.join("\r\n")}\r\n`, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": "attachment; filename=profesor-go-hallazgos.csv",
      "Cache-Control": "private, no-store",
    },
  });
}
