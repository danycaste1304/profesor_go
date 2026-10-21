import type { InputHTMLAttributes, ReactNode, TextareaHTMLAttributes } from "react";

export const inputClasses =
  "block w-full rounded-xl border border-[#d6deeb] bg-white px-3.5 py-2.5 text-sm text-[#172443] shadow-sm placeholder:text-[#96a1b5] focus:border-cyan-500 focus:outline-none focus:ring-2 focus:ring-cyan-500/20 disabled:bg-slate-100 aria-[invalid=true]:border-red-500";

export interface FieldProps {
  label: string;
  htmlFor?: string;
  error?: string;
  hint?: ReactNode;
  children: ReactNode;
}

/** Label + control + hint/error wrapper shared by Input, Textarea and Select. */
export function Field({ label, htmlFor, error, hint, children }: FieldProps) {
  return (
    <div className="space-y-1">
      <label htmlFor={htmlFor} className="block text-sm font-medium text-slate-700">
        {label}
      </label>
      {children}
      {hint ? <div className="text-xs text-slate-500">{hint}</div> : null}
      {error ? (
        <p className="text-sm text-red-600" role="alert">
          {error}
        </p>
      ) : null}
    </div>
  );
}

export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: string;
  hint?: ReactNode;
}

export function Input({ label, error, hint, id, name, className = "", ...props }: InputProps) {
  const inputId = id ?? name;
  return (
    <Field label={label} htmlFor={inputId} error={error} hint={hint}>
      <input
        id={inputId}
        name={name}
        aria-invalid={error ? true : undefined}
        className={`${inputClasses} ${className}`.trim()}
        {...props}
      />
    </Field>
  );
}

export interface TextareaProps extends TextareaHTMLAttributes<HTMLTextAreaElement> {
  label: string;
  error?: string;
  hint?: ReactNode;
}

export function Textarea({ label, error, hint, id, name, className = "", ...props }: TextareaProps) {
  const inputId = id ?? name;
  return (
    <Field label={label} htmlFor={inputId} error={error} hint={hint}>
      <textarea
        id={inputId}
        name={name}
        aria-invalid={error ? true : undefined}
        className={`${inputClasses} min-h-24 ${className}`.trim()}
        {...props}
      />
    </Field>
  );
}
