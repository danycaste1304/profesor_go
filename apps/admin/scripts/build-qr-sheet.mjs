import { readFile, writeFile } from "node:fs/promises";
import QRCode from "qrcode";

const [source, destination] = process.argv.slice(2);
if (!source || !destination) {
  throw new Error("Usage: node scripts/build-qr-sheet.mjs <private-json> <output-html>");
}

const codes = JSON.parse(await readFile(source, "utf8"));
if (!Array.isArray(codes) || codes.length === 0) throw new Error("No QR codes found");
const escapeHtml = (value) => String(value).replace(/[&<>"']/g, (character) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
})[character]);
const expectedPrefix = "https://danycaste1304.github.io/profesor_go/jugar/#qr=";
const cards = await Promise.all(codes.map(async ({ name, url }) => {
  if (typeof name !== "string" || typeof url !== "string" ||
      !url.startsWith(expectedPrefix) || !/^[A-Za-z0-9_-]{43}$/.test(url.slice(expectedPrefix.length))) {
    throw new Error(`Invalid QR record for ${name}`);
  }
  const image = await QRCode.toDataURL(url, {
    errorCorrectionLevel: "H", margin: 3, width: 900,
  });
  return `<article class="card"><div class="brand">PROFESOR GO · USFQ</div><h1>${escapeHtml(name)}</h1><img src="${image}" alt="QR de ${escapeHtml(name)}"><p>Escanea para encontrar a este profesor</p><div class="id">Código ${escapeHtml(url.slice(-6))}</div></article>`;
}));
const pages = [];
for (let i = 0; i < cards.length; i += 2) {
  pages.push(`<section class="page">${cards.slice(i, i + 2).join("")}</section>`);
}
const html = `<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Profesor GO · QR de profesores</title><meta name="robots" content="noindex,nofollow"><style>
@page{size:A4 portrait;margin:12mm}*{box-sizing:border-box}body{margin:0;font-family:Arial,sans-serif;color:#172443;background:#e8edf4}.page{width:210mm;min-height:297mm;margin:12px auto;padding:12mm;background:white;display:flex;flex-direction:column;gap:8mm;page-break-after:always}.page:last-child{page-break-after:auto}.card{height:126mm;border:2px dashed #a1aab7;border-radius:12px;text-align:center;padding:5mm;display:flex;flex-direction:column;align-items:center}.brand{font-size:11pt;font-weight:800;letter-spacing:1.5px;color:#3f7795}h1{font-size:22pt;margin:2mm 0 0}img{width:78mm;height:78mm;object-fit:contain}p{font-size:11pt;margin:0}.id{font-size:9pt;color:#5b6574;margin-top:auto}@media print{body{background:white}.page{margin:0;padding:0;width:auto;min-height:auto;gap:8mm}.card{break-inside:avoid}}
</style></head><body>${pages.join("")}</body></html>`;
await writeFile(destination, html, { mode: 0o600 });
console.log(`Created ${codes.length} QR cards across ${pages.length} print pages.`);
