import * as React from "react";
import { cn } from "@/lib/utils";

type Props = React.HTMLAttributes<HTMLDivElement> & { variant?: "error" | "warning" | "info" };

export function Alert({ className, variant = "info", ...props }: Props) {
  return (
    <div
      role={variant === "error" ? "alert" : "status"}
      className={cn(
        "rounded-md border px-4 py-3 text-sm",
        variant === "error" && "border-red-400/50 bg-red-500/10 text-red-200",
        variant === "warning" && "border-amber-400/50 bg-amber-500/10 text-amber-200",
        variant === "info" && "border-aqua/40 bg-aqua/10 text-slate-100",
        className,
      )}
      {...props}
    />
  );
}
