import type { ReactNode, SelectHTMLAttributes } from "react";
import { Field, inputClasses } from "./Input";

export interface SelectOption {
  value: string;
  label: string;
  disabled?: boolean;
}

export interface SelectProps extends SelectHTMLAttributes<HTMLSelectElement> {
  label: string;
  options: SelectOption[];
  /** Adds an empty first option with this text. */
  placeholder?: string;
  error?: string;
  hint?: ReactNode;
}

export function Select({
  label,
  options,
  placeholder,
  error,
  hint,
  id,
  name,
  className = "",
  ...props
}: SelectProps) {
  const selectId = id ?? name;
  return (
    <Field label={label} htmlFor={selectId} error={error} hint={hint}>
      <select
        id={selectId}
        name={name}
        aria-invalid={error ? true : undefined}
        className={`${inputClasses} ${className}`.trim()}
        {...props}
      >
        {placeholder !== undefined ? <option value="">{placeholder}</option> : null}
        {options.map((option) => (
          <option key={option.value} value={option.value} disabled={option.disabled}>
            {option.label}
          </option>
        ))}
      </select>
    </Field>
  );
}
