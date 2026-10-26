const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const source = fs.readFileSync(path.join(__dirname, "../docs/anfitrion.js"), "utf8");

function harness({ assigned = true, accuracy = 15 } = {}) {
  const elements = new Map();
  const calls = [];
  for (const id of ["status", "signed-out", "signed-in", "account", "not-linked",
    "linked", "professor-name", "inactive", "active", "start", "stop",
    "update-now", "logout", "login", "reload-assignment", "countdown",
    "last-position"]) {
    elements.set(id, {
      textContent: "",
      dataset: {},
      hidden: false,
      disabled: false,
      listeners: {},
      addEventListener(name, callback) { this.listeners[name] = callback; },
    });
  }
  const session = {
    id: "session-1",
    professor_id: "professor-1",
    started_at: new Date().toISOString(),
    ends_at: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
    stopped_at: null,
  };
  const client = {
    auth: {
      getSession: async () => ({ data: { session: {} }, error: null }),
      getUser: async () => ({ data: { user: { id: "publisher-1", email: "professor@test.local" } }, error: null }),
      signInWithOAuth: async () => ({ error: null }),
      signOut: async () => ({ error: null }),
    },
    from(table) {
      return {
        select() { return this; }, eq() { return this; }, is() { return this; },
        gt() { return this; }, order() { return this; }, limit() { return this; },
        async maybeSingle() {
          return table === "hunt_publishers"
            ? { data: assigned ? { professor_id: "professor-1", professors: { display_name: "Prof. Noel" } } : null, error: null }
            : { data: null, error: null };
        },
      };
    },
    async rpc(name, params) {
      calls.push({ name, params });
      if (name === "start_campus_hunt") return { data: session, error: null };
      if (name === "update_campus_hunt_location") {
        return { data: { ...session, located_at: new Date().toISOString() }, error: null };
      }
      if (name === "stop_campus_hunt") return { data: true, error: null };
      throw new Error(`Unexpected RPC: ${name}`);
    },
  };
  const document = {
    hidden: false,
    getElementById(id) { return elements.get(id); },
    addEventListener() {},
  };
  const window = {
    isSecureContext: true,
    location: { origin: "https://example.test", pathname: "/anfitrion.html" },
    addEventListener() {},
  };
  const navigator = {
    geolocation: {
      getCurrentPosition(success) {
        success({ coords: { latitude: -0.1969, longitude: -78.4362, accuracy } });
      },
    },
  };
  vm.runInNewContext(source, {
    document, window, navigator,
    supabase: { createClient: () => client },
    setInterval: () => 1, clearInterval: () => {},
    Date, Promise, Number, String, Math,
  });
  const flush = async () => {
    for (let i = 0; i < 5; i++) await new Promise((resolve) => setImmediate(resolve));
  };
  return { elements, calls, flush };
}

test("an authorized host publishes and stops a 30-minute hunt", async () => {
  const app = harness();
  await app.flush();
  assert.equal(app.elements.get("professor-name").textContent, "Prof. Noel");
  assert.equal(app.elements.get("inactive").hidden, false);

  app.elements.get("start").listeners.click();
  await app.flush();
  assert.deepEqual(app.calls.map((call) => call.name), [
    "start_campus_hunt", "update_campus_hunt_location",
  ]);
  assert.equal(app.calls[1].params.p_accuracy_m, 15);
  assert.equal(app.elements.get("active").hidden, false);

  app.elements.get("stop").listeners.click();
  await app.flush();
  assert.equal(app.calls.at(-1).name, "stop_campus_hunt");
  assert.equal(app.elements.get("active").hidden, true);
});

test("poor GPS does not start the server timer", async () => {
  const app = harness({ accuracy: 150 });
  await app.flush();
  app.elements.get("start").listeners.click();
  await app.flush();
  assert.equal(app.calls.length, 0);
  assert.match(app.elements.get("status").textContent, /GPS es impreciso/);
});

test("a signed-in account without an assignment cannot publish", async () => {
  const app = harness({ assigned: false });
  await app.flush();
  assert.equal(app.elements.get("not-linked").hidden, false);
  assert.equal(app.elements.get("linked").hidden, true);
  app.elements.get("start").listeners.click();
  await app.flush();
  assert.equal(app.calls.length, 0);
});
