/** CORS headers shared by every Edge Function (the mobile app and the admin call them cross-origin). */
export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

export function isPreflight(req: Request): boolean {
  return req.method === "OPTIONS";
}

/** Empty 204 response carrying the CORS headers, for OPTIONS preflight requests. */
export function preflightResponse(): Response {
  return new Response(null, { status: 204, headers: corsHeaders });
}
