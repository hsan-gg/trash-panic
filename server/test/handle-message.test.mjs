import { test } from "node:test";
import assert from "node:assert/strict";
import { handleMessage } from "../src/index.js";

test("valid ping gets a pong with the same id", () => {
  assert.deepEqual(handleMessage('{"t":"ping","id":7,"net":"5G_SA"}'), { t: "pong", id: 7 });
});

test("rejects unknown network types, bad ids, junk and oversized messages", () => {
  for (const bad of [
    '{"t":"ping","id":7,"net":"6G"}',
    '{"t":"ping","id":-1,"net":"4G"}',
    '{"t":"ping","id":"7","net":"4G"}',
    '{"t":"hack"}',
    "null",
    "not json",
    '{"t":"ping","id":1,"net":"4G","pad":"' + "x".repeat(300) + '"}',
  ]) {
    assert.equal(handleMessage(bad), null, bad);
  }
});
