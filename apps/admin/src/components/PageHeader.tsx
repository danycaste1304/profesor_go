import type { ReactNode } from "react";

export function PageHeader({
  title,
  description,
  actions,
}: {
  title: string;
  description?: string;
  actions?: ReactNode;
}) {
  return (
    <div className="mb-7 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <p className="mb-1.5 text-[11px] font-black uppercase tracking-[0.2em] text-[#158c9d]">Profesor GO / Admin</p>
        <h1 className="text-3xl font-black tracking-tight text-[#15203b] sm:text-4xl">{title}</h1>
        {description ? <p className="mt-2 text-sm text-[#66748f]">{description}</p> : null}
      </div>
      {actions ? <div className="flex shrink-0 gap-2">{actions}</div> : null}
    </div>
  );
}
