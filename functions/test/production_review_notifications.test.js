"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const {
  notificationContent,
  notificationKey,
  deepLink,
} = require("../remote/monitoring");

const productionReviewEventTypes = [
  "technical_validation_completed",
  "owner_review_required",
  "owner_review_changes_requested",
  "r2_revision_ready",
  "revision_started",
  "revision_completed",
  "registration_ready",
  "production_failed",
  "recovery_action_required",
];

describe("production review notifications", () => {
  for (const eventType of productionReviewEventTypes) {
    it(`notificationContent handles ${eventType}`, () => {
      const content = notificationContent(
        eventType,
        15,
        "소유자 검토",
        1,
        { productType: "app", appName: "테스트앱" }
      );
      assert.ok(content.title, `${eventType} title`);
      assert.ok(content.body, `${eventType} body`);
      assert.match(content.title, /./);
      assert.match(content.body, /./);
    });
  }

  it("notificationKey dedupes by eventType and revision", () => {
    const base = {
      ownerUid: "uid_a",
      instructionId: "wi_plan_app_r1",
      jobId: "job_1",
      stageId: "owner_review",
      revision: 1,
      artifactId: "",
    };
    const keys = productionReviewEventTypes.map((eventType) =>
      notificationKey({ ...base, eventType })
    );
    const unique = new Set(keys);
    assert.equal(unique.size, keys.length, "each eventType should produce unique key");
  });

  it("duplicate keys match for same eventType payload", () => {
    const payload = {
      ownerUid: "uid_a",
      instructionId: "wi_plan_app_r1",
      jobId: "job_1",
      stageId: "owner_review",
      revision: 1,
      eventType: "owner_review_changes_requested",
    };
    assert.equal(notificationKey(payload), notificationKey(payload));
  });

  it("deepLink includes revision query when present", () => {
    const link = deepLink({
      eventType: "owner_review_changes_requested",
      instructionId: "wi_plan_app_r1",
      stageId: "owner_review",
      revision: "R1",
    });
    assert.match(link, /revision=R1/);
    assert.match(link, /screen=ai-production/);
    assert.match(link, /projectId=wi_plan_app_r1/);
  });

  it("deepLink formats numeric revision as R-prefix", () => {
    const link = deepLink({
      eventType: "r2_revision_ready",
      instructionId: "wi_x",
      stageId: "owner_review",
      revision: 2,
    });
    assert.match(link, /revision=R2/);
  });

  it("owner_review_changes_requested content mentions 보완", () => {
    const content = notificationContent(
      "owner_review_changes_requested",
      15,
      "소유자 검토",
      1,
      {}
    );
    assert.match(content.title, /보완/);
  });

  it("technical_validation_completed content mentions 기술검증", () => {
    const content = notificationContent(
      "technical_validation_completed",
      15,
      "소유자 검토",
      1,
      {}
    );
    assert.match(content.title, /기술검증/);
  });
});
