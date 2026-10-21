"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

function NavIcon({ kind }: { kind: "grid" | "people" | "nfc" }) {
  const paths = {
    grid: <><rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" /><rect x="3" y="14" width="7" height="7" rx="1" /><rect x="14" y="14" width="7" height="7" rx="1" /></>,
    people: <><circle cx="9" cy="8" r="3" /><path d="M3 20v-2a6 6 0 0 1 12 0v2H3Z" /><path d="M17 5a3 3 0 0 1 0 6M18 14a5 5 0 0 1 3 5v1h-3" /></>,
    nfc: <><rect x="3" y="3" width="18" height="18" rx="3" /><path d="M7 17V7l10 10V7M10 10l4 4" /></>,
  };
  return <svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">{paths[kind]}</svg>;
}

const links = [
  { href: "/dashboard", label: "Resumen", icon: "grid" },
  { href: "/professors", label: "Profesores", icon: "people" },
  { href: "/nfc", label: "Tarjetas NFC", icon: "nfc" },
];

export function NavLinks() {
  const pathname = usePathname();
  return (
    <ul className="flex gap-1 md:flex-col">
      {links.map((link) => {
        const active = pathname === link.href || pathname.startsWith(`${link.href}/`);
        return (
          <li key={link.href}>
            <Link
              href={link.href}
              aria-current={active ? "page" : undefined}
              className={`focus-ring flex items-center gap-3 whitespace-nowrap rounded-xl px-3 py-2.5 text-sm font-semibold transition-colors ${
                active ? "bg-[#ffd447] text-[#101b34] shadow-[3px_3px_0_#02091d]" : "text-[#cbd6ec] hover:bg-white/10 hover:text-white"
              }`}
            >
              <NavIcon kind={link.icon as "grid" | "people" | "nfc"} />
              {link.label}
            </Link>
          </li>
        );
      })}
    </ul>
  );
}
