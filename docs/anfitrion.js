/* global supabase */
(() => {
  "use strict";

  // This is a publishable browser key, never a service-role key. The database
  // checks the signed-in user's assignment on every write.
  const SUPABASE_URL = "https://zwvnyejxettnjbuallgm.supabase.co";
  const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_J836wMU_6tEaeamYqakgOA_6xhwwjGR";
  const LOCATION_INTERVAL_MS = 10000;
  const MAX_ACCURACY_METERS = 100;

  const byId = (id) => document.getElementById(id);
  const client = supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
    auth: {
      flowType: "pkce",
      detectSessionInUrl: true,
      persistSession: true,
      autoRefreshToken: true,
      storageKey: "profesor-go-hunt-host",
    },
  });

  let user = null;
  let publisher = null;
  let session = null;
  let busy = false;
  let publishing = false;
  let locationTimer = null;
  let countdownTimer = null;
  let finishing = false;

  function status(message, tone = "info") {
    const element = byId("status");
    element.textContent = message;
    element.dataset.tone = tone;
  }

  function visible(id, show) {
    byId(id).hidden = !show;
  }

  function sessionActive() {
    return session && !session.stopped_at && Date.now() < Date.parse(session.ends_at);
  }

  function render() {
    const signedIn = Boolean(user);
    visible("signed-out", !signedIn);
    visible("signed-in", signedIn);
    if (!signedIn) return;

    byId("account").textContent = user.email || "Cuenta de Google";
    visible("not-linked", !publisher);
    visible("linked", Boolean(publisher));
    if (publisher) {
      const related = publisher.professors;
      byId("professor-name").textContent = Array.isArray(related)
        ? related[0]?.display_name || "Profesor"
        : related?.display_name || "Profesor";
    }
    const active = Boolean(sessionActive());
    visible("inactive", !active);
    visible("active", active);
    byId("start").disabled = busy;
    byId("stop").disabled = busy;
    byId("update-now").disabled = busy || publishing;
    byId("logout").disabled = busy;
    if (active) renderCountdown();
  }

  function renderCountdown() {
    if (!session) return;
    const seconds = Math.max(0, Math.ceil((Date.parse(session.ends_at) - Date.now()) / 1000));
    byId("countdown").textContent = `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
    if (seconds === 0 && !finishing) void finishExpired();
  }

  function stopTimers() {
    if (locationTimer) clearInterval(locationTimer);
    if (countdownTimer) clearInterval(countdownTimer);
    locationTimer = null;
    countdownTimer = null;
  }

  function startTimers() {
    stopTimers();
    countdownTimer = setInterval(renderCountdown, 1000);
    locationTimer = setInterval(() => {
      if (!document.hidden) void publishLocation();
    }, LOCATION_INTERVAL_MS);
    renderCountdown();
  }

  function describeError(error, fallback) {
    if (error?.code === "42501") return "Esta cuenta no está autorizada o la búsqueda ya terminó.";
    if (error?.code === "PGRST202") return "La función de búsqueda no está disponible. Avisa al organizador.";
    return fallback;
  }

  function currentPosition() {
    if (!window.isSecureContext || !navigator.geolocation) {
      return Promise.reject(new Error("Abre esta página mediante HTTPS en Safari para usar la ubicación."));
    }
    return new Promise((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(resolve, (error) => {
        const message = error.code === 1
          ? "Permite la ubicación para esta página en Safari."
          : error.code === 3
            ? "El GPS tardó demasiado. Sal a un espacio abierto e inténtalo de nuevo."
            : "No se pudo obtener la ubicación. Revisa la señal GPS.";
        reject(new Error(message));
      }, { enableHighAccuracy: true, maximumAge: 3000, timeout: 8000 });
    });
  }

  function validatePosition(point) {
    const { latitude, longitude, accuracy } = point.coords;
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude) ||
        !Number.isFinite(accuracy) || accuracy > MAX_ACCURACY_METERS) {
      throw new Error("El GPS es impreciso (más de 100 m). Muévete a un espacio abierto.");
    }
    return { latitude, longitude, accuracy };
  }

  async function publishLocation(point) {
    if (!sessionActive() || publishing || document.hidden) return;
    publishing = true;
    render();
    try {
      const coords = validatePosition(point || await currentPosition());
      const { data, error } = await client.rpc("update_campus_hunt_location", {
        p_session_id: session.id,
        p_latitude: coords.latitude,
        p_longitude: coords.longitude,
        p_accuracy_m: coords.accuracy,
      });
      if (error) throw error;
      session = data;
      const time = new Date(data.located_at).toLocaleTimeString("es-EC", {
        hour: "2-digit", minute: "2-digit", second: "2-digit",
      });
      byId("last-position").textContent = `Última ubicación enviada: ${time} · precisión ±${Math.round(coords.accuracy)} m`;
      status("Compartiendo tu posición aproximada. Mantén Safari abierto.", "success");
    } catch (error) {
      status(describeError(error, error.message || "No se pudo actualizar el GPS. El marcador desaparecerá si pasan 30 segundos."), "error");
    } finally {
      publishing = false;
      render();
    }
  }

  async function start() {
    if (busy || !publisher) return;
    busy = true;
    render();
    try {
      const point = await currentPosition();
      validatePosition(point);
      const { data, error } = await client.rpc("start_campus_hunt", {
        p_professor_id: publisher.professor_id,
      });
      if (error) throw error;
      session = data;
      render();
      startTimers();
      await publishLocation(point);
    } catch (error) {
      status(describeError(error, error.message || "No se pudo iniciar la búsqueda."), "error");
    } finally {
      busy = false;
      render();
    }
  }

  async function stop() {
    if (busy || !session) return false;
    busy = true;
    render();
    try {
      const { error } = await client.rpc("stop_campus_hunt", { p_session_id: session.id });
      if (error) throw error;
      stopTimers();
      session = null;
      byId("last-position").textContent = "Esperando señal GPS…";
      status("Búsqueda detenida. Tu ubicación ya no se muestra.", "success");
      return true;
    } catch (error) {
      status(describeError(error, "No se pudo detener la búsqueda. Inténtalo de nuevo."), "error");
      return false;
    } finally {
      busy = false;
      render();
    }
  }

  async function finishExpired() {
    finishing = true;
    stopTimers();
    if (session) {
      await client.rpc("stop_campus_hunt", { p_session_id: session.id });
    }
    session = null;
    finishing = false;
    status("Los 30 minutos terminaron. La ubicación dejó de ser visible.", "success");
    render();
  }

  async function loadAssignment() {
    const { data: assignment, error: assignmentError } = await client
      .from("hunt_publishers")
      .select("professor_id, professors(display_name)")
      .eq("user_id", user.id)
      .maybeSingle();
    if (assignmentError) throw assignmentError;
    publisher = assignment;
    session = null;
    if (publisher) {
      const { data: active, error: sessionError } = await client
        .from("hunt_sessions")
        .select("id, professor_id, started_at, ends_at, stopped_at, latitude, longitude, accuracy_m, located_at")
        .eq("publisher_id", user.id)
        .is("stopped_at", null)
        .gt("ends_at", new Date().toISOString())
        .order("started_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (sessionError) throw sessionError;
      session = active;
    }
    render();
    if (sessionActive()) {
      startTimers();
      if (!document.hidden) void publishLocation();
      status("Búsqueda activa. Mantén Safari abierto.", "success");
    } else if (publisher) {
      status("Cuenta vinculada. Puedes iniciar la búsqueda cuando estés listo.");
    } else {
      status("Entraste con Google. Falta que el organizador vincule tu cuenta.");
    }
  }

  async function boot() {
    try {
      const { error: sessionError } = await client.auth.getSession();
      if (sessionError) throw sessionError;
      const { data, error } = await client.auth.getUser();
      if (error && error.name !== "AuthSessionMissingError") throw error;
      user = data.user;
      render();
      if (user) await loadAssignment();
      else status("Inicia sesión con la cuenta autorizada para compartir ubicación.");
    } catch (_) {
      user = null;
      render();
      status("No se pudo comprobar la sesión. Revisa internet y recarga la página.", "error");
    }
  }

  byId("login").addEventListener("click", async () => {
    byId("login").disabled = true;
    const { error } = await client.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: window.location.origin + window.location.pathname },
    });
    if (error) {
      status("No se pudo abrir Google. Inténtalo de nuevo.", "error");
      byId("login").disabled = false;
    }
  });
  byId("reload-assignment").addEventListener("click", async () => {
    try { await loadAssignment(); }
    catch (_) { status("No se pudo comprobar la vinculación. Inténtalo de nuevo.", "error"); }
  });
  byId("start").addEventListener("click", () => { void start(); });
  byId("stop").addEventListener("click", () => { void stop(); });
  byId("update-now").addEventListener("click", () => { void publishLocation(); });
  byId("logout").addEventListener("click", async () => {
    if (sessionActive() && !await stop()) return;
    stopTimers();
    await client.auth.signOut();
    user = null;
    publisher = null;
    session = null;
    render();
    status("Sesión cerrada. Ya no compartes tu ubicación.");
  });
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden && sessionActive()) void publishLocation();
  });
  window.addEventListener("pagehide", stopTimers);
  window.addEventListener("pageshow", (event) => {
    if (event.persisted && sessionActive()) {
      startTimers();
      void publishLocation();
    }
  });

  void boot();
})();
