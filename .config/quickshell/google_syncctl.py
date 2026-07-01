#!/usr/bin/env python3
from __future__ import annotations

import base64
import hashlib
import json
import secrets
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any


AUTH_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"
USERINFO_ENDPOINT = "https://www.googleapis.com/oauth2/v3/userinfo"
SCOPES = "openid email profile"
TIMEOUT_SECONDS = 300


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    sys.stdout.flush()


def _b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def _post_json(url: str, data: dict[str, str]) -> dict[str, Any]:
    encoded = urllib.parse.urlencode(data).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=encoded,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        try:
            details = json.loads(body)
        except json.JSONDecodeError:
            details = {"error": body}
        error = details.get("error_description") or details.get("error") or str(exc)
        raise RuntimeError(str(error)) from exc


def _get_json(url: str, access_token: str) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        headers={"Authorization": f"Bearer {access_token}"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        try:
            details = json.loads(body)
        except json.JSONDecodeError:
            details = {"error": body}
        error = details.get("error_description") or details.get("error") or str(exc)
        raise RuntimeError(str(error)) from exc


def _open_browser(url: str) -> None:
    try:
        subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


class OAuthCallback:
    def __init__(self, expected_state: str) -> None:
        self.expected_state = expected_state
        self.event = threading.Event()
        self.code = ""
        self.error = ""


def _handler(callback: OAuthCallback) -> type[BaseHTTPRequestHandler]:
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt: str, *args: object) -> None:
            return

        def do_GET(self) -> None:
            parsed = urllib.parse.urlparse(self.path)
            params = urllib.parse.parse_qs(parsed.query)

            if parsed.path != "/oauth2callback":
                self.send_response(404)
                self.end_headers()
                return

            state = params.get("state", [""])[0]
            error = params.get("error", [""])[0]
            code = params.get("code", [""])[0]

            if state != callback.expected_state:
                callback.error = "OAuth state mismatch."
            elif error:
                callback.error = error
            elif not code:
                callback.error = "OAuth callback did not include an authorization code."
            else:
                callback.code = code

            html = (
                "<!doctype html><meta charset='utf-8'>"
                "<title>Reimagined Google sync</title>"
                "<style>body{font-family:sans-serif;background:#111;color:#eee;"
                "display:grid;place-items:center;height:100vh;margin:0}"
                "main{max-width:420px;padding:24px;border-radius:18px;background:#202124}"
                "</style><main><h2>Google sync</h2>"
                "<p>You can close this tab and return to Settings.</p></main>"
            )
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(html.encode("utf-8"))))
            self.end_headers()
            self.wfile.write(html.encode("utf-8"))
            callback.event.set()

    return Handler


def connect(client_id: str, login_hint: str = "") -> int:
    client_id = client_id.strip()
    login_hint = login_hint.strip()

    if not client_id:
        emit({
            "event": "error",
            "state": "not_connected",
            "message": "Google OAuth Client ID is required.",
        })
        return 2

    state = secrets.token_urlsafe(24)
    verifier = secrets.token_urlsafe(64)
    challenge = _b64url(hashlib.sha256(verifier.encode("ascii")).digest())
    callback = OAuthCallback(state)

    server = ThreadingHTTPServer(("127.0.0.1", 0), _handler(callback))
    port = int(server.server_address[1])
    redirect_uri = f"http://127.0.0.1:{port}/oauth2callback"
    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()

    params = {
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": SCOPES,
        "state": state,
        "access_type": "offline",
        "prompt": "consent",
        "code_challenge": challenge,
        "code_challenge_method": "S256",
    }
    if login_hint:
        params["login_hint"] = login_hint

    auth_url = AUTH_ENDPOINT + "?" + urllib.parse.urlencode(params)
    emit({
        "event": "connecting",
        "state": "connecting",
        "authUrl": auth_url,
        "message": "Complete Google sign-in in the browser. Waiting for the local OAuth callback.",
    })
    _open_browser(auth_url)

    try:
        if not callback.event.wait(TIMEOUT_SECONDS):
            raise RuntimeError("Google sign-in timed out.")
        if callback.error:
            raise RuntimeError(callback.error)

        token = _post_json(TOKEN_ENDPOINT, {
            "client_id": client_id,
            "code": callback.code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirect_uri,
        })
        access_token = str(token.get("access_token", ""))
        if not access_token:
            raise RuntimeError("Google did not return an access token.")

        profile = _get_json(USERINFO_ENDPOINT, access_token)
        display_name = str(profile.get("name") or profile.get("email") or "").strip()
        email = str(profile.get("email") or "").strip()
        avatar = str(profile.get("picture") or "").strip()
        expires_at = ""
        if isinstance(token.get("expires_in"), int):
            expires_at = time.strftime("%Y-%m-%d %H:%M", time.localtime(time.time() + int(token["expires_in"])))

        emit({
            "event": "connected",
            "state": "connected",
            "displayName": display_name,
            "email": email,
            "avatar": avatar,
            "lastSync": time.strftime("%Y-%m-%d %H:%M"),
            "tokenExpiresAt": expires_at,
            "message": "",
        })
        return 0
    except Exception as exc:
        emit({
            "event": "error",
            "state": "not_connected",
            "message": f"Google sign-in failed: {exc}",
        })
        return 1
    finally:
        server.shutdown()
        server.server_close()


def main(argv: list[str]) -> int:
    command = argv[1] if len(argv) > 1 else ""
    if command == "connect":
        client_id = argv[2] if len(argv) > 2 else ""
        login_hint = argv[3] if len(argv) > 3 else ""
        return connect(client_id, login_hint)

    emit({
        "event": "error",
        "state": "not_connected",
        "message": f"Unknown command: {command or '<empty>'}",
    })
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
