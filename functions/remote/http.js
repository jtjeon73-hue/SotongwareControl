"use strict";

function httpError(status, error, message) {
  const err = new Error(message || error);
  err.httpStatus = status;
  err.error = error;
  return err;
}

function sendError(res, err) {
  const status = err.httpStatus || 500;
  const error = err.error || (status >= 500 ? "internal" : "error");
  const body = {
    ok: false,
    error,
  };
  if (status < 500 && err.message && err.message !== error) {
    body.message = String(err.message).slice(0, 200);
  }
  res.status(status).json(body);
}

function sendOk(res, payload = {}) {
  res.status(200).json({ ok: true, ...payload });
}

module.exports = { httpError, sendError, sendOk };
