import Image from "next/image";

export function BrandMark({ small = false }: { small?: boolean }) {
  const size = small ? 36 : 48;
  return (
    <span
      aria-hidden="true"
      className="inline-flex shrink-0 overflow-hidden rounded-xl shadow-[0_5px_12px_-5px_#07172e99]"
    >
      <Image
        src="/profesor-go-icon.svg"
        alt=""
        width={size}
        height={size}
        priority={!small}
      />
    </span>
  );
}
