import type { Metadata } from "next";
import Link from "next/link";
import "./globals.css";

export const metadata: Metadata = {
  title: "AquaOS | AI Water Intelligence Platform",
  description: "Borewell and pumping hydraulics analysis with plain-language explanations.",
};

const navLink =
  "rounded px-2 py-1 text-sm text-slate-300 hover:text-aqua focus-visible:outline-2 focus-visible:outline-aqua";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="flex min-h-full flex-col">
        <header className="border-b border-line bg-navy-800">
          <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
            <Link href="/" className="text-lg font-bold tracking-tight text-white focus-visible:outline-2 focus-visible:outline-aqua">
              Aqua<span className="text-aqua">OS</span>
            </Link>
            <nav aria-label="Main" className="flex gap-2">
              <Link href="/" className={navLink}>Dashboard</Link>
              <Link href="/calculator" className={navLink}>Calculator</Link>
            </nav>
          </div>
        </header>
        <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-8">{children}</main>
        <footer className="border-t border-line px-4 py-4 text-center text-xs text-slate-400">
          AquaOS estimates are for planning only and do not replace a site survey by a qualified engineer.
        </footer>
      </body>
    </html>
  );
}
