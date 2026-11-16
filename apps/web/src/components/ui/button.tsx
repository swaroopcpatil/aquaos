import * as React from "react";
import { cn } from "@/lib/utils";

type Props = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "outline";
};

export function Button({ className, variant = "primary", ...props }: Props) {
  return (
    <button
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded-md px-4 py-2 text-sm font-semibold transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-aqua disabled:cursor-not-allowed disabled:opacity-60",
        variant === "primary" && "bg-aqua text-navy-950 hover:bg-aqua/85",
        variant === "outline" && "border border-line text-slate-100 hover:bg-navy-700",
        className,
      )}
      {...props}
    />
  );
}

export function linkButtonClass(variant: "primary" | "outline" = "primary") {
  return cn(
    "inline-flex items-center justify-center gap-2 rounded-md px-4 py-2 text-sm font-semibold transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-aqua",
    variant === "primary" ? "bg-aqua text-navy-950 hover:bg-aqua/85" : "border border-line hover:bg-navy-700",
  );
}
