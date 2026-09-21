"use strict";

/**
 * Work ↔ Control ebook commercial v2 stage contract drift guard.
 * Fixture is the shared SSOT snapshot of kStagesV2 / ebookWorkflowStages.
 */
const assert = require("node:assert/strict");
const { describe, it } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  EBOOK_STAGE_CONTRACTS,
  EBOOK_STAGE_IDS,
  EBOOK_COMMERCIAL_V2_STAGE_IDS,
  EBOOK_STAGE_BY_ID,
  resolveEbookStageMeta,
  normalizeEbookStageId,
} = require("../sotong24/canonical");
const { parseArtifactUploadInit } = require("../sotong24/artifact");

const fixture = JSON.parse(
  fs.readFileSync(
    path.join(__dirname, "../../test/fixtures/ebook_commercial_v2_stages.json"),
    "utf8"
  )
);

describe("ebook commercial v2 stage contract (Work↔Control)", () => {
  it("primary EBOOK_STAGE_CONTRACTS matches fixture 18 stages", () => {
    assert.equal(EBOOK_STAGE_CONTRACTS.length, 18);
    assert.equal(EBOOK_STAGE_IDS.length, 18);
    assert.deepEqual(
      EBOOK_COMMERCIAL_V2_STAGE_IDS,
      fixture.stages.map((s) => s.stageId)
    );
    for (let i = 0; i < fixture.stages.length; i++) {
      const expected = fixture.stages[i];
      const actual = EBOOK_STAGE_CONTRACTS[i];
      assert.equal(
        actual.id,
        expected.stageId,
        `ebook stage contract drift at order ${expected.order}: expected ${expected.stageId}, got ${actual.id}`
      );
      assert.equal(actual.order, expected.order);
      assert.equal(actual.approvalTypicallyRequired, expected.approvalGate);
      assert.equal(actual.aiDocumentStage, expected.artifactUpload);
    }
  });

  it("STEP13-18 ids are present (no unknown_ebook_stageId)", () => {
    for (const id of [
      "format_build",
      "reader_accessibility_test",
      "package_user_review",
      "final_polish",
      "final_user_approval",
      "publication_package",
    ]) {
      assert.ok(
        EBOOK_STAGE_BY_ID.has(id),
        `ebook stage contract drift: missing ${id}`
      );
    }
  });

  it("known failure stageIds from Golden Run are now mapped", () => {
    for (const id of [
      "editorial_structure_review",
      "cover_layout_design",
      "package_user_review",
    ]) {
      assert.ok(resolveEbookStageMeta(id), `missing mapping for ${id}`);
    }
  });

  it("sales_metadata normalizes to package_user_review", () => {
    assert.equal(normalizeEbookStageId("sales_metadata"), "package_user_review");
    assert.equal(resolveEbookStageMeta("sales_metadata").id, "package_user_review");
  });

  it("legacy aliases remain accepted but are not primary order", () => {
    for (const id of fixture.legacyAliases) {
      assert.ok(
        resolveEbookStageMeta(id) || EBOOK_STAGE_BY_ID.has(id),
        `legacy alias missing: ${id}`
      );
    }
    assert.ok(!EBOOK_STAGE_IDS.includes("build_test"));
    assert.ok(!EBOOK_STAGE_IDS.includes("maintain"));
  });

  it("guessed wrong names final_policy/release_package stay rejected", () => {
    for (const id of fixture.unknownMustReject) {
      assert.equal(resolveEbookStageMeta(id), null);
      assert.ok(!EBOOK_STAGE_BY_ID.has(id));
    }
  });

  it("artifact init allows every commercial v2 artifact-capable stage", () => {
    for (const stage of fixture.stages) {
      if (!stage.artifactUpload) continue;
      const parsed = parseArtifactUploadInit({
        instructionId: "wi_test_remote_e2e_contract_v2",
        productType: "ebook",
        stageId: stage.stageId,
        stageNumber: stage.order,
        revision: 1,
        fileName: "stage_note.md",
        contentType: "text/markdown; charset=utf-8",
        sizeBytes: 128,
        isTest: true,
      });
      assert.equal(parsed.stageId, stage.stageId, stage.stageId);
      assert.ok(
        parsed.storagePath.includes(`/${stage.stageId}/`),
        parsed.storagePath
      );
    }
  });

  it("artifact init PASS for package_user_review / cover / editorial", () => {
    for (const [stageId, order] of [
      ["package_user_review", 15],
      ["cover_layout_design", 12],
      ["editorial_structure_review", 8],
    ]) {
      const parsed = parseArtifactUploadInit({
        instructionId: "wi_test_remote_e2e_contract_v2",
        productType: "ebook",
        stageId,
        stageNumber: order,
        revision: 1,
        fileName: "book.pdf",
        contentType: "application/pdf",
        sizeBytes: 4096,
        isTest: true,
      });
      assert.equal(parsed.stageId, stageId);
    }
  });

  it("artifact init rejects foo_bar_invalid (fail-closed)", () => {
    assert.throws(
      () =>
        parseArtifactUploadInit({
          instructionId: "wi_test_remote_e2e_contract_v2",
          productType: "ebook",
          stageId: "foo_bar_invalid",
          stageNumber: 1,
          revision: 1,
          fileName: "x.md",
          contentType: "text/markdown; charset=utf-8",
          sizeBytes: 32,
          isTest: true,
        }),
      /unknown_ebook_stageId:foo_bar_invalid/
    );
  });

  it("package_user_review upload does not imply approval (gate flag only)", () => {
    const meta = EBOOK_STAGE_BY_ID.get("package_user_review");
    assert.equal(meta.approvalTypicallyRequired, true);
    assert.equal(meta.order, 15);
    // Artifact success only enables reviewReady path; approval is separate.
    assert.notEqual(meta.artifactKind, "auto_approve");
  });
});
