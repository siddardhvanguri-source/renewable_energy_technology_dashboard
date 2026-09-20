import { describe, expect, it } from "vitest";
import { appRouter } from "./routers";
import type { TrpcContext } from "./_core/context";

describe("dashboard.snapshot", () => {
  it("returns a telemetry-shaped response without requiring auth", async () => {
    const ctx = {
      user: null,
      req: {} as TrpcContext["req"],
      res: {} as TrpcContext["res"],
    } satisfies TrpcContext;
    const result = await appRouter.createCaller(ctx).dashboard.snapshot({ deviceKey: "array-a" });
    expect(result.latest).toMatchObject({ vPv: expect.any(Number), pPv: expect.any(Number), duty: expect.any(Number) });
    expect(result).toHaveProperty("history");
    expect(result).toHaveProperty("settings");
  });
});
