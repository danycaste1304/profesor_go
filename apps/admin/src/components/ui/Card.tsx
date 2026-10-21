import type { ReactNode } from "react";

export interface CardProps {
  title?: string;
  description?: string;
  actions?: ReactNode;
  children: ReactNode;
  className?: string;
}

export function Card({ title, description, actions, children, className = "" }: CardProps) {
  return (
    <section className={`rounded-2xl border border-[#dfe5ef] bg-white p-5 shadow-[0_10px_35px_-25px_#14203b66] sm:p-6 ${className}`.trim()}>
      {title || actions ? (
        <header className="mb-4 flex items-start justify-between gap-4">
          <div>
            {title ? <h2 className="text-base font-bold text-[#172443]">{title}</h2> : null}
            {description ? <p className="mt-1 text-sm leading-relaxed text-[#65718b]">{description}</p> : null}
          </div>
          {actions}
        </header>
      ) : null}
      {children}
    </section>
  );
}
