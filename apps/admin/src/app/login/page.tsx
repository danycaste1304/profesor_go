import type { Metadata } from "next";
import { LoginForm } from "@/components/LoginForm";
import { BrandMark } from "@/components/BrandMark";
import { Card } from "@/components/ui";
import { NOT_ADMIN_ERROR, NOT_ADMIN_MESSAGE } from "@/lib/constants";

export const metadata: Metadata = { title: "Iniciar sesión" };

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  const initialError = error === NOT_ADMIN_ERROR ? NOT_ADMIN_MESSAGE : undefined;

  return (
    <main className="pixel-grid flex min-h-screen items-center justify-center p-4 sm:p-8">
      <div className="grid w-full max-w-4xl overflow-hidden rounded-[26px] border border-[#cbd5e6] bg-white shadow-[0_24px_70px_-38px_#10203d99] md:grid-cols-[1fr_1fr]">
        <div className="relative hidden min-h-[480px] flex-col justify-between overflow-hidden bg-[#172443] p-9 text-white md:flex">
          <div className="absolute -right-14 top-24 h-64 w-64 rounded-full border-[34px] border-[#344b70]" aria-hidden="true" />
          <div className="absolute bottom-28 right-20 h-24 w-24 rotate-12 border-[14px] border-[#ffd447]" aria-hidden="true" />
          <div className="relative flex items-center gap-3"><BrandMark /><span className="text-xl font-black tracking-tight">PROFESOR <span className="text-[#ffd447]">GO</span></span></div>
          <div className="relative">
            <p className="mb-3 text-xs font-black uppercase tracking-[0.2em] text-[#7ee7ed]">Centro de control</p>
            <h1 className="text-4xl font-black leading-tight tracking-tight">La feria está<br /><span className="text-[#ffd447]">en tus manos.</span></h1>
            <p className="mt-4 max-w-xs text-sm leading-relaxed text-[#c6d3eb]">Prepara el catálogo, vincula las tarjetas y sigue el progreso de la aventura.</p>
          </div>
        </div>
        <div className="flex min-h-[480px] flex-col justify-center p-6 sm:p-10">
          <div className="mb-8 md:hidden"><BrandMark /><p className="mt-4 text-xl font-black text-[#172443]">PROFESOR <span className="text-[#148999]">GO</span></p></div>
          <div className="mb-6">
            <p className="mb-1 text-[11px] font-black uppercase tracking-[0.2em] text-[#158c9d]">Administración</p>
            <h2 className="text-3xl font-black tracking-tight text-[#172443]">Bienvenido de nuevo</h2>
            <p className="mt-2 text-sm text-[#66748f]">Inicia sesión con tu cuenta de administrador.</p>
          </div>
          <Card className="!border-0 !p-0 !shadow-none">
            <LoginForm initialError={initialError} />
          </Card>
        </div>
      </div>
    </main>
  );
}
