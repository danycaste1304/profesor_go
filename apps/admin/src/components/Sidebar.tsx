import Link from "next/link";
import { BrandMark } from "@/components/BrandMark";
import { NavLinks } from "@/components/NavLinks";
import { Button } from "@/components/ui";
import { signOut } from "@/lib/actions/auth";

/** Responsive shell navigation: top bar on phones, left sidebar from md up. */
export function Sidebar({ email }: { email: string }) {
  return (
    <aside className="relative z-10 flex flex-col border-b border-[#111d39] bg-[#111c38] text-white md:sticky md:top-0 md:h-screen md:w-64 md:shrink-0 md:border-b-0 md:border-r md:border-r-[#26375b]">
      <div className="flex items-center justify-between gap-3 px-4 py-4 md:px-5 md:pb-7 md:pt-7">
        <Link href="/dashboard" className="focus-ring flex items-center gap-3 rounded-xl">
          <BrandMark small />
          <span className="min-w-0">
            <span className="block text-base font-black tracking-tight">PROFESOR <span className="text-[#ffd447]">GO</span></span>
            <span className="block text-[10px] font-semibold uppercase tracking-[0.18em] text-[#8fa5c9]">Centro de control</span>
          </span>
        </Link>
        <form action={signOut} className="md:hidden">
          <Button type="submit" variant="secondary" size="sm" aria-label="Cerrar sesión">
            Salir
          </Button>
        </form>
      </div>
      <div className="hidden px-5 pb-3 text-[10px] font-bold uppercase tracking-[0.2em] text-[#7790b9] md:block">Administración</div>
      <nav aria-label="Principal" className="overflow-x-auto px-3 pb-3 md:flex-1 md:px-3">
        <NavLinks />
      </nav>
      <div className="hidden border-t border-white/10 px-5 py-5 md:block">
        <p className="mb-1 text-[10px] font-bold uppercase tracking-[0.17em] text-[#7790b9]">Sesión activa</p>
        <p className="truncate text-xs text-[#d1ddf2]" title={email}>
          {email}
        </p>
        <form action={signOut} className="mt-3">
          <Button type="submit" variant="secondary" size="sm" className="w-full">
            Cerrar sesión
          </Button>
        </form>
      </div>
    </aside>
  );
}
