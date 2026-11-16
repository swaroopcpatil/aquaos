import * as React from "react";
import { cn } from "@/lib/utils";

export const fieldClass =
  "w-full rounded-md border border-line bg-navy-950 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500 focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-aqua aria-[invalid=true]:border-red-400";

export function Input({ className, ...props }: React.InputHTMLAttributes<HTMLInputElement>) {
  return <input className={cn(fieldClass, className)} {...props} />;
}

export function Textarea({ className, ...props }: React.TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return <textarea className={cn(fieldClass, className)} {...props} />;
}
