import type { ReactNode } from "react";

interface Children {
  children: ReactNode;
  className?: string;
}

export function Table({ children, className = "" }: Children) {
  return (
    <div className="overflow-x-auto rounded-2xl border border-[#dfe5ef] bg-white shadow-[0_10px_35px_-25px_#14203b66]">
      <table className={`min-w-full divide-y divide-[#e4e9f2] text-sm ${className}`.trim()}>
        {children}
      </table>
    </div>
  );
}

export function THead({ children }: Children) {
  return <thead className="bg-[#f7f9fd]">{children}</thead>;
}

export function TBody({ children }: Children) {
  return <tbody className="divide-y divide-[#edf0f5] bg-white">{children}</tbody>;
}

export function Tr({ children, className = "" }: Children) {
  return <tr className={`transition-colors hover:bg-[#fafbfe] ${className}`.trim()}>{children}</tr>;
}

export function Th({ children, className = "" }: Children) {
  return (
    <th
      scope="col"
      className={`px-5 py-4 text-left text-[11px] font-bold uppercase tracking-[0.13em] text-[#66738d] ${className}`.trim()}
    >
      {children}
    </th>
  );
}

export function Td({ children, className = "" }: Children) {
  return <td className={`px-5 py-4 align-middle text-[#23324f] ${className}`.trim()}>{children}</td>;
}

export function EmptyRow({ colSpan, children }: { colSpan: number; children: ReactNode }) {
  return (
    <tr>
      <td colSpan={colSpan} className="px-4 py-10 text-center text-sm text-slate-500">
        {children}
      </td>
    </tr>
  );
}
