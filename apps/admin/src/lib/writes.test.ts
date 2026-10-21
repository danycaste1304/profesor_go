import { describe, expect, it } from "vitest";
import { NO_ROWS_REASON, interpretWrite } from "./writes";

describe("interpretWrite", () => {
  it("returns the rows when the write affected at least one row", () => {
    const outcome = interpretWrite({ data: [{ id: "a" }], error: null }, "actualizar", "el profesor");
    expect(outcome.ok).toBe(true);
    if (!outcome.ok) return;
    expect(outcome.rows).toEqual([{ id: "a" }]);
  });

  it("accepts a single object (result of .single()/.maybeSingle())", () => {
    const outcome = interpretWrite({ data: { id: "a" }, error: null }, "guardar", "el profesor");
    expect(outcome.ok && outcome.rows).toEqual([{ id: "a" }]);
  });

  it("fails on an empty array: PostgREST does not error when 0 rows match", () => {
    const outcome = interpretWrite({ data: [], error: null }, "actualizar", "el profesor");
    expect(outcome.ok).toBe(false);
    if (outcome.ok) return;
    expect(outcome.message).toBe(`No se pudo actualizar el profesor: ${NO_ROWS_REASON}`);
  });

  it("fails on null data (no rows returned at all)", () => {
    const outcome = interpretWrite({ data: null, error: null }, "crear", "el tag NFC");
    expect(outcome.ok).toBe(false);
    if (outcome.ok) return;
    expect(outcome.message).toContain("No se pudo crear el tag NFC");
    expect(outcome.message).toContain("ninguna fila");
  });

  it("propagates a PostgREST error message", () => {
    const outcome = interpretWrite(
      { data: null, error: { message: "new row violates row-level security policy" } },
      "guardar",
      "el profesor",
    );
    expect(outcome.ok).toBe(false);
    if (outcome.ok) return;
    expect(outcome.message).toBe(
      "No se pudo guardar el profesor: new row violates row-level security policy",
    );
  });

  it("prefers the error over any returned data", () => {
    const outcome = interpretWrite({ data: [{ id: "a" }], error: { message: "boom" } }, "guardar", "el profesor");
    expect(outcome.ok).toBe(false);
  });

  it("writes every message in Spanish, starting with the subject and verb", () => {
    for (const action of ["guardar", "crear", "actualizar"] as const) {
      const outcome = interpretWrite({ data: [], error: null }, action, "el tag NFC");
      expect(outcome.ok).toBe(false);
      if (outcome.ok) return;
      expect(outcome.message.startsWith(`No se pudo ${action} el tag NFC`)).toBe(true);
    }
  });
});
