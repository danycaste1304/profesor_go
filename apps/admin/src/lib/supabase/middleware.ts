import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { NOT_ADMIN_ERROR } from "@/lib/constants";
import { getSupabaseEnv } from "./env";

const PUBLIC_PATHS = ["/login"];

function isPublicPath(pathname: string): boolean {
  return PUBLIC_PATHS.some((p) => pathname === p || pathname.startsWith(`${p}/`));
}

/** Builds a redirect that keeps any auth cookies written on `from`. */
function redirectWithCookies(request: NextRequest, target: string, from: NextResponse): NextResponse {
  const url = request.nextUrl.clone();
  const [pathname, search = ""] = target.split("?");
  url.pathname = pathname;
  url.search = search ? `?${search}` : "";
  const response = NextResponse.redirect(url);
  for (const cookie of from.cookies.getAll()) {
    response.cookies.set(cookie);
  }
  return response;
}

/**
 * Refreshes the Supabase session (official @supabase/ssr pattern) and applies the
 * auth guard: anonymous users go to /login, non-admin users are signed out with
 * `?error=not_admin`, and signed-in admins never see /login again.
 */
export async function updateSession(request: NextRequest): Promise<NextResponse> {
  let supabaseResponse = NextResponse.next({ request });
  const { url, anonKey } = getSupabaseEnv();

  const supabase = createServerClient(url, anonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        supabaseResponse = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) =>
          supabaseResponse.cookies.set(name, value, options),
        );
      },
    },
  });

  // IMPORTANT: no code between createServerClient and getUser (it refreshes the token).
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { pathname } = request.nextUrl;
  const publicPath = isPublicPath(pathname);

  if (!user) {
    return publicPath ? supabaseResponse : redirectWithCookies(request, "/login", supabaseResponse);
  }

  // Signed in: only profiles.role = 'admin' may use the panel (CONTRACTS §8).
  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();

  if (profile?.role !== "admin") {
    await supabase.auth.signOut();
    return redirectWithCookies(request, `/login?error=${NOT_ADMIN_ERROR}`, supabaseResponse);
  }

  if (publicPath || pathname === "/") {
    return redirectWithCookies(request, "/dashboard", supabaseResponse);
  }

  return supabaseResponse;
}
