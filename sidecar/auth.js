const GITHUB_DEVICE_CODE_URL = "https://github.com/login/device/code";
const GITHUB_ACCESS_TOKEN_URL = "https://github.com/login/oauth/access_token";

export async function startDeviceFlow(clientId) {
  const resolvedClientId = normalizeClientId(clientId);
  if (!resolvedClientId) {
    throw new Error("Missing GitHub OAuth client ID");
  }

  const body = new URLSearchParams({
    client_id: resolvedClientId,
    scope: "read:user user:email",
  });

  const response = await fetch(GITHUB_DEVICE_CODE_URL, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload.error_description ?? "Unable to start device flow");
  }

  return {
    client_id: resolvedClientId,
    device_code: payload.device_code,
    user_code: payload.user_code,
    verification_uri: payload.verification_uri,
    verification_uri_complete: payload.verification_uri_complete,
    interval: payload.interval ?? 5,
    expires_in: payload.expires_in,
  };
}

export async function pollDeviceFlow(clientId, deviceCode) {
  const resolvedClientId = normalizeClientId(clientId);
  if (!resolvedClientId || !deviceCode) {
    throw new Error("Missing client ID or device code");
  }

  const body = new URLSearchParams({
    client_id: resolvedClientId,
    device_code: deviceCode,
    grant_type: "urn:ietf:params:oauth:grant-type:device_code",
  });

  const response = await fetch(GITHUB_ACCESS_TOKEN_URL, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });

  const payload = await response.json();

  if (payload.error) {
    return {
      ok: false,
      status: payload.error,
      error_description: payload.error_description,
      interval: payload.interval,
    };
  }

  if (!response.ok || !payload.access_token) {
    throw new Error(payload.error_description ?? "Unable to retrieve access token");
  }

  return {
    ok: true,
    status: "authorized",
    access_token: payload.access_token,
    token_type: payload.token_type,
    scope: payload.scope,
  };
}

function normalizeClientId(clientId) {
  return (
    clientId ??
    process.env.COPILOTFORGE_GITHUB_CLIENT_ID ??
    process.env.GITHUB_OAUTH_CLIENT_ID ??
    ""
  ).trim();
}
