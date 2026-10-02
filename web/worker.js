export default {
  async fetch(request, env) {
    if (request.method === "PUT") {
      const body = await request.text();

      await env.LOGS.put("log", body);

      return new Response("OK");
    }

    if (request.method === "GET") {
      const log = await env.LOGS.get("log");

      return new Response(log || "No log");
    }

    return new Response("Method not allowed", { status: 405 });
  }
};