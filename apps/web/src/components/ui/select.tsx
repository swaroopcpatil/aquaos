import * as React from "react";
import { cn } from "@/lib/utils";
import { fieldClass } from "./input";

export function Select({ className, ...props }: React.SelectHTMLAttributes<HTMLSelectElement>) {
  return <select className={cn(fieldClass, className)} {...props} />;
}
