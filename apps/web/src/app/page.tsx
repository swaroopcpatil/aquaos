import Link from "next/link";
import { ApiStatus } from "@/components/api-status";
import { Card, CardTitle } from "@/components/ui/card";
import { linkButtonClass } from "@/components/ui/button";

export default function Dashboard() {
  return (
    <div className="space-y-8">
      <section>
        <p className="text-sm font-semibold uppercase tracking-widest text-aqua">Water intelligence platform</p>
        <h1 className="mt-2 text-3xl font-bold tracking-tight text-white sm:text-4xl">
          Size borewell pumps with engineering-grade hydraulics
        </h1>
        <p className="mt-3 max-w-2xl text-slate-300">
          AquaOS computes total dynamic head, friction losses and motor power from your borewell
          geometry using a deterministic calculation, then explains the result in plain language
          for farmers, dealers or technicians.
        </p>
      </section>
      <div className="grid gap-6 md:grid-cols-2">
        <ApiStatus />
        <Card>
          <CardTitle>Borewell hydraulic analysis</CardTitle>
          <p className="text-sm text-slate-300">
            Enter water levels, pipe details and flow rate to get TDH, power requirements, a
            head breakdown and a to-scale borewell cross-section.
          </p>
          <Link href="/calculator" className={`${linkButtonClass()} mt-4`}>
            Open calculator
          </Link>
        </Card>
      </div>
    </div>
  );
}
