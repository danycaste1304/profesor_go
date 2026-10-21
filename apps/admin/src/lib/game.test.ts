import { describe, expect, it } from "vitest";
import { MAX_SPRITE_BYTES } from "./constants";
import {
  DEFAULT_CAPTURE_RATE,
  RARITIES,
  RARITY_LABELS,
  SPRITE_ACCEPT_ATTRIBUTE,
  SPRITE_MIME_TYPES,
  fileExtension,
  formatMaxBytes,
  formatRate,
  isRarity,
  isSvgUrl,
  normalizeAdminStats,
  normalizeMimeType,
  parseRate,
  spriteExtension,
  validateProfessorInput,
  validateSpriteFile,
} from "./game";

const validRaw = {
  name: "  Ada Lovelace ",
  display_name: "Prof. Ada",
  description: "",
  rarity: "COMMON",
  base_capture_rate: "0.8",
  sprite_url: "",
  active: "on",
};

describe("RARITIES / DEFAULT_CAPTURE_RATE", () => {
  it("matches CONTRACTS §1", () => {
    expect(RARITIES).toEqual(["COMMON", "RARE", "EPIC", "LEGENDARY"]);
    expect(DEFAULT_CAPTURE_RATE).toEqual({ COMMON: 0.8, RARE: 0.6, EPIC: 0.4, LEGENDARY: 0.25 });
  });

  it("has a Spanish label for every rarity", () => {
    for (const rarity of RARITIES) {
      expect(RARITY_LABELS[rarity]).toBeTruthy();
    }
  });

  it("isRarity only accepts the four enum values", () => {
    expect(isRarity("EPIC")).toBe(true);
    expect(isRarity("epic")).toBe(false);
    expect(isRarity("MYTHIC")).toBe(false);
    expect(isRarity(null)).toBe(false);
  });
});

describe("parseRate", () => {
  it("parses numbers and numeric strings", () => {
    expect(parseRate(0.5)).toBe(0.5);
    expect(parseRate("0.8")).toBe(0.8);
    expect(parseRate("0,25")).toBe(0.25);
    expect(parseRate(".5")).toBe(0.5);
    expect(parseRate("1")).toBe(1);
  });

  it("rejects garbage", () => {
    expect(parseRate("")).toBeNull();
    expect(parseRate("abc")).toBeNull();
    expect(parseRate("1e2")).toBeNull();
    expect(parseRate(NaN)).toBeNull();
    expect(parseRate(undefined)).toBeNull();
  });
});

describe("validateProfessorInput", () => {
  it("normalizes a valid payload", () => {
    const result = validateProfessorInput(validRaw);
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.value).toEqual({
      name: "Ada Lovelace",
      display_name: "Prof. Ada",
      description: null,
      rarity: "COMMON",
      base_capture_rate: 0.8,
      sprite_url: null,
      active: true,
    });
  });

  it("accepts typed values (number rate, boolean active, lowercase rarity)", () => {
    const result = validateProfessorInput({
      ...validRaw,
      rarity: "legendary",
      base_capture_rate: 0.25,
      active: false,
      sprite_url: "https://example.test/sprite.png",
      description: "  Pionera  ",
    });
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.value.rarity).toBe("LEGENDARY");
    expect(result.value.base_capture_rate).toBe(0.25);
    expect(result.value.active).toBe(false);
    expect(result.value.sprite_url).toBe("https://example.test/sprite.png");
    expect(result.value.description).toBe("Pionera");
  });

  it("treats a missing checkbox as inactive", () => {
    const result = validateProfessorInput({ ...validRaw, active: undefined });
    expect(result.ok && result.value.active).toBe(false);
  });

  it("requires name and display_name", () => {
    const result = validateProfessorInput({ ...validRaw, name: "   ", display_name: "" });
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.errors.name).toBeDefined();
    expect(result.errors.display_name).toBeDefined();
    expect(Object.keys(result.errors)).toHaveLength(2);
  });

  it("rejects an invalid rarity", () => {
    const result = validateProfessorInput({ ...validRaw, rarity: "MYTHIC" });
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.errors.rarity).toBeDefined();
  });

  it("rejects rates outside 0..1 and non-numeric rates", () => {
    for (const rate of ["1.5", "-0.1", "abc", ""]) {
      const result = validateProfessorInput({ ...validRaw, base_capture_rate: rate });
      expect(result.ok).toBe(false);
      if (result.ok) return;
      expect(result.errors.base_capture_rate).toBeDefined();
    }
    expect(validateProfessorInput({ ...validRaw, base_capture_rate: "0" }).ok).toBe(true);
    expect(validateProfessorInput({ ...validRaw, base_capture_rate: "1" }).ok).toBe(true);
  });

  it("rejects a non-http sprite url and over-long text", () => {
    const result = validateProfessorInput({
      ...validRaw,
      sprite_url: "ftp://nope",
      description: "x".repeat(501),
      name: "y".repeat(81),
    });
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.errors.sprite_url).toBeDefined();
    expect(result.errors.description).toBeDefined();
    expect(result.errors.name).toBeDefined();
  });
});

describe("formatRate", () => {
  it("formats as a Spanish percentage", () => {
    expect(formatRate(0.8)).toBe("80 %");
    expect(formatRate(0.25)).toBe("25 %");
    expect(formatRate(0.255)).toBe("25,5 %");
    expect(formatRate(0)).toBe("0 %");
    expect(formatRate(1)).toBe("100 %");
  });

  it("handles non-finite input", () => {
    expect(formatRate(NaN)).toBe("—");
  });
});

describe("normalizeAdminStats", () => {
  const stats = { total_players: 12, total_captures: "34", active_professors: 8, completed_collections: 2 };

  it("accepts a plain object", () => {
    expect(normalizeAdminStats(stats)).toEqual({
      total_players: 12,
      total_captures: 34,
      active_professors: 8,
      completed_collections: 2,
    });
  });

  it("accepts a one-row array", () => {
    expect(normalizeAdminStats([stats]).total_players).toBe(12);
  });

  it("defaults to zeros", () => {
    expect(normalizeAdminStats(null)).toEqual({
      total_players: 0,
      total_captures: 0,
      active_professors: 0,
      completed_collections: 0,
    });
    expect(normalizeAdminStats({ total_players: "many" }).total_players).toBe(0);
  });
});

describe("spriteExtension", () => {
  it("uses the file name extension when it looks like one", () => {
    expect(spriteExtension("ada.png", "image/png")).toBe("png");
    expect(spriteExtension("ADA.PNG", "image/png")).toBe("png");
    expect(spriteExtension("mi sprite raro.WebP", "image/webp")).toBe("webp");
    expect(spriteExtension("archive.tar.gif", "image/gif")).toBe("gif");
  });

  it("falls back to the MIME type when the name has no usable extension", () => {
    expect(spriteExtension("sprite", "image/png")).toBe("png");
    expect(spriteExtension("sprite", "image/jpeg")).toBe("jpg");
    expect(spriteExtension("sprite", "image/webp")).toBe("webp");
    expect(spriteExtension("sprite", "image/gif")).toBe("gif");
    expect(spriteExtension("captura.2026-09-17", "image/png")).toBe("png");
  });

  it("falls back to png for unknown types", () => {
    expect(spriteExtension("sprite", "image/avif")).toBe("png");
    expect(spriteExtension("", "")).toBe("png");
  });
});

describe("spriteExtension (allowlist)", () => {
  it("ignores a name extension that does not match the MIME type", () => {
    expect(spriteExtension("evil.svg", "image/png")).toBe("png");
    expect(spriteExtension("sprite.exe", "image/gif")).toBe("gif");
    expect(spriteExtension("foto.jpeg", "image/jpeg")).toBe("jpeg");
  });

  it("never returns svg, whatever the input", () => {
    expect(spriteExtension("evil.svg", "image/svg+xml")).toBe("png");
  });

  it("tolerates MIME parameters and casing", () => {
    expect(spriteExtension("sprite", "IMAGE/WEBP")).toBe("webp");
    expect(spriteExtension("sprite", "image/jpeg; charset=binary")).toBe("jpg");
  });
});

describe("fileExtension / normalizeMimeType / isSvgUrl / formatMaxBytes", () => {
  it("extracts a plausible extension only", () => {
    expect(fileExtension("ada.PNG")).toBe("png");
    expect(fileExtension("sprite")).toBe("");
    expect(fileExtension("captura.2026-09-17")).toBe("");
    expect(fileExtension("")).toBe("");
  });

  it("normalizes MIME types", () => {
    expect(normalizeMimeType("image/PNG")).toBe("image/png");
    expect(normalizeMimeType(" image/jpeg; charset=utf-8 ")).toBe("image/jpeg");
    expect(normalizeMimeType(undefined)).toBe("");
  });

  it("detects svg urls ignoring query and hash", () => {
    expect(isSvgUrl("https://cdn.test/a/evil.svg")).toBe(true);
    expect(isSvgUrl("https://cdn.test/a/evil.svg?token=1")).toBe(true);
    expect(isSvgUrl("https://cdn.test/a/ada.png")).toBe(false);
    expect(isSvgUrl("https://cdn.test/a/sprite")).toBe(false);
  });

  it("formats the size cap", () => {
    expect(formatMaxBytes(MAX_SPRITE_BYTES)).toBe("2 MB");
    expect(formatMaxBytes(512 * 1024)).toBe("0,5 MB");
  });
});

describe("validateSpriteFile", () => {
  const png = { name: "ada.png", type: "image/png", size: 1024 };

  it("accepts every raster type in the allowlist", () => {
    const samples = [
      { name: "a.png", type: "image/png", size: 10, extension: "png" },
      { name: "a.jpg", type: "image/jpeg", size: 10, extension: "jpg" },
      { name: "a.jpeg", type: "image/jpeg", size: 10, extension: "jpeg" },
      { name: "a.webp", type: "image/webp", size: 10, extension: "webp" },
      { name: "a.gif", type: "image/gif", size: 10, extension: "gif" },
    ];
    for (const sample of samples) {
      const result = validateSpriteFile(sample);
      expect(result.ok).toBe(true);
      if (!result.ok) return;
      expect(result.contentType).toBe(sample.type);
      expect(result.extension).toBe(sample.extension);
    }
  });

  it("rejects SVG (stored-XSS vector in a public bucket)", () => {
    const result = validateSpriteFile({ name: "evil.svg", type: "image/svg+xml", size: 200 });
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.message).toContain("SVG");
  });

  it("rejects an SVG renamed to .png and a PNG renamed to .svg", () => {
    expect(validateSpriteFile({ name: "evil.png", type: "image/svg+xml", size: 200 }).ok).toBe(false);
    expect(validateSpriteFile({ name: "evil.svg", type: "image/png", size: 200 }).ok).toBe(false);
  });

  it("rejects other non-raster types and missing types", () => {
    expect(validateSpriteFile({ name: "a.html", type: "text/html", size: 10 }).ok).toBe(false);
    expect(validateSpriteFile({ name: "a.pdf", type: "application/pdf", size: 10 }).ok).toBe(false);
    expect(validateSpriteFile({ name: "a.png", type: "", size: 10 }).ok).toBe(false);
  });

  it("requires an extension on the file name", () => {
    const result = validateSpriteFile({ name: "sprite", type: "image/png", size: 10 });
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.message).toContain("extensión");
  });

  it("caps the size and rejects empty files", () => {
    expect(validateSpriteFile({ ...png, size: MAX_SPRITE_BYTES }).ok).toBe(true);
    const tooBig = validateSpriteFile({ ...png, size: MAX_SPRITE_BYTES + 1 });
    expect(tooBig.ok).toBe(false);
    if (tooBig.ok) return;
    expect(tooBig.message).toContain("2 MB");
    expect(validateSpriteFile({ ...png, size: 0 }).ok).toBe(false);
    expect(validateSpriteFile({ ...png, size: NaN }).ok).toBe(false);
  });

  it("honours a custom cap", () => {
    expect(validateSpriteFile({ ...png, size: 2048 }, 1024).ok).toBe(false);
  });

  it("offers an accept attribute without svg", () => {
    expect(SPRITE_ACCEPT_ATTRIBUTE).not.toContain("svg");
    for (const mime of SPRITE_MIME_TYPES) {
      expect(SPRITE_ACCEPT_ATTRIBUTE).toContain(mime);
    }
  });
});

describe("validateProfessorInput sprite_url", () => {
  it("rejects an svg sprite url even when the URL itself is well formed", () => {
    const result = validateProfessorInput({ ...validRaw, sprite_url: "https://cdn.test/evil.svg" });
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.errors.sprite_url).toContain("SVG");
  });

  it("still accepts a raster sprite url", () => {
    const result = validateProfessorInput({ ...validRaw, sprite_url: "https://cdn.test/ada.png" });
    expect(result.ok).toBe(true);
  });
});
