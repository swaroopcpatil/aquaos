"use client";

import { useCallback, useEffect, useState } from "react";
import { API_BASE_URL, getHealth, type HealthResponse } from "@/lib/api";
import { Card, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";

type State =
  | { s: "loading" }
  | { s: "online"; data: HealthResponse }
  | { s: "offline" };

export function ApiStatus() {
  const [state, setState] = useState<State>({ s: "loading" });

  const check = useCallback(() => {
    setState({ s: "loading" });
    getHealth().then(
      (data) => setState({ s: "online", data }),
      () => setState({ s: "offline" }),
    );
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    check();
  }, [check]);

  const dot =
    state.s === "online" ? "bg-emerald-400" : state.s === "offline" ? "bg-red-400" : "bg-amber-400 animate-pulse";

  return (
    <Card>
      <CardTitle>API status</CardTitle>
      <div className="flex items-center gap-2" role="status" aria-live="polite">
        <span className={`h-3 w-3 rounded-full ${dot}`} aria-hidden="true" />
        <span className="font-medium">
          {state.s === "loading" && "Checking..."}
          {state.s === "online" && "Online"}
          {state.s === "offline" && "Offline"}
        </span>
      </div>
      <p className="mt-2 text-sm text-slate-400">
        {state.s === "online" && `${state.data.service} v${state.data.version}`}
        {state.s === "offline" && `Cannot reach ${API_BASE_URL}. Start the backend to run calculations.`}
        {state.s === "loading" && `Contacting ${API_BASE_URL}`}
      </p>
      <Button variant="outline" className="mt-4" onClick={check} disabled={state.s === "loading"}>
        Recheck
      </Button>
    </Card>
  );
}
