import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "Profesor GO · Admin",
    template: "%s · Profesor GO Admin",
  },
  description: "Panel de administración de Profesor GO",
  icons: { icon: "/profesor-go-icon.svg" },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="es">
      <body className="min-h-screen font-sans text-[#15203b] antialiased">{children}</body>
    </html>
  );
}
