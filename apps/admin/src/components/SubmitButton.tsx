"use client";

import { useFormStatus } from "react-dom";
import { Button, type ButtonProps } from "@/components/ui";

interface SubmitButtonProps extends ButtonProps {
  pendingText?: string;
}

/** Submit button that disables itself while the enclosing form action is pending. */
export function SubmitButton({ children, pendingText = "Guardando…", disabled, ...props }: SubmitButtonProps) {
  const { pending } = useFormStatus();
  return (
    <Button type="submit" disabled={pending || disabled} aria-busy={pending} {...props}>
      {pending ? pendingText : children}
    </Button>
  );
}
