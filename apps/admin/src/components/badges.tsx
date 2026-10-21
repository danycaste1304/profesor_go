import { Badge, type BadgeTone } from "@/components/ui";
import { RARITY_LABELS, isRarity, type Rarity } from "@/lib/game";

const rarityTone: Record<Rarity, BadgeTone> = {
  COMMON: "neutral",
  RARE: "info",
  EPIC: "purple",
  LEGENDARY: "amber",
};

/** Rarity always carries a text label besides the color (accessibility). */
export function RarityBadge({ rarity }: { rarity: string }) {
  if (!isRarity(rarity)) return <Badge>{rarity}</Badge>;
  return <Badge tone={rarityTone[rarity]}>{RARITY_LABELS[rarity]}</Badge>;
}

export function ActiveBadge({ active }: { active: boolean }) {
  return active ? <Badge tone="success">Activo</Badge> : <Badge tone="neutral">Inactivo</Badge>;
}
