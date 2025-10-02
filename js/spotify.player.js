// Minimal Spotify Web Playback integration using PKCE (no client secret in browser)
// Fill in YOUR values below before deploying.
const SPOTIFY_CLIENT_ID = "CLIENT_ID";
const REDIRECT_URI = "https://localhost:8080/>"; // e.g., https://game.example.com/
const PLAYLIST_ID = "3uuQ3HbcZagjXAlBMzpKVg"; // tracks are sampled from here

async function sha256(plain) {
  const encoder = new TextEncoder();
  const data = encoder.encode(plain);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return btoa(String.fromCharCode(...new Uint8Array(digest)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function randStr(n=64) {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";
  let out = "";
  for (let i = 0; i < n; i++) out += chars.charAt(Math.floor(Math.random()*chars.length));
  return out;
}

async function pkceLogin(scopes) {
  const verifier = randStr();
  const challenge = await sha256(verifier);
  sessionStorage.setItem("pkce_verifier", verifier);

  const url = new URL("https://accounts.spotify.com/authorize");
  url.searchParams.set("client_id", SPOTIFY_CLIENT_ID);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("redirect_uri", REDIRECT_URI);
  url.searchParams.set("scope", scopes);
  url.searchParams.set("code_challenge_method", "S256");
  url.searchParams.set("code_challenge", challenge);
  window.location = url.toString();
}

async function exchangeCodeForToken(authCode) {
  const verifier = sessionStorage.getItem("pkce_verifier");
  const body = new URLSearchParams({
    client_id: SPOTIFY_CLIENT_ID,
    grant_type: "authorization_code",
    code: authCode,
    redirect_uri: REDIRECT_URI,
    code_verifier: verifier
  });
  const res = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body
  });
  if (!res.ok) throw new Error("Token exchange failed");
  const json = await res.json();
  localStorage.setItem("spotify_tokens", JSON.stringify({
    access_token: json.access_token,
    refresh_token: json.refresh_token,
    expires_at: Date.now() + (json.expires_in * 1000) - 15000
  }));
  return json.access_token;
}

async function getAccessToken() {
  const raw = localStorage.getItem("spotify_tokens");
  if (!raw) return null;
  const tokens = JSON.parse(raw);
  if (Date.now() < tokens.expires_at) return tokens.access_token;

  // refresh
  const body = new URLSearchParams({
    client_id: SPOTIFY_CLIENT_ID,
    grant_type: "refresh_token",
    refresh_token: tokens.refresh_token
  });
  const res = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body
  });
  if (!res.ok) return null;
  const json = await res.json();
  tokens.access_token = json.access_token;
  tokens.expires_at = Date.now() + (json.expires_in * 1000) - 15000;
  localStorage.setItem("spotify_tokens", JSON.stringify(tokens));
  return tokens.access_token;
}

async function ensureToken() {
  const url = new URL(window.location.href);
  const code = url.searchParams.get("code");
  if (code) {
    await exchangeCodeForToken(code);
    url.searchParams.delete("code");
    window.history.replaceState({}, "", url.toString());
  }
  let token = await getAccessToken();
  if (!token) {
    const SCOPES = [
      "streaming",
      "user-read-email",
      "user-modify-playback-state",
      "user-read-playback-state",
      "playlist-read-private"
    ].join(" ");
    await pkceLogin(SCOPES);
    return null; // navigation will happen
  }
  return token;
}

function loadSdk() {
  return new Promise((resolve) => {
    if (window.Spotify) return resolve();
    const s = document.createElement("script");
    s.src = "https://sdk.scdn.co/spotify-player.js";
    s.onload = resolve;
    document.head.appendChild(s);
  });
}

export const spotifyPlayer = (() => {
  let deviceId = null;
  let accessToken = null;

  async function initPlayer() {
    accessToken = await ensureToken();
    if (!accessToken) return; // pkceLogin redirected

    await loadSdk();
    return new Promise((resolve) => {
      window.onSpotifyWebPlaybackSDKReady = () => {
        const player = new Spotify.Player({
          name: "MazeRunner Web Player",
          getOAuthToken: cb => cb(accessToken),
          volume: 0.7
        });
        player.addListener("ready", ({ device_id }) => {
          deviceId = device_id;
          resolve();
        });
        player.addListener("initialization_error", ({ message }) => console.error(message));
        player.addListener("authentication_error", ({ message }) => console.error(message));
        player.addListener("account_error", ({ message }) => console.error(message));
        player.connect();
      };
    });
  }

  async function getRandomTrack() {
    const res = await fetch(`https://api.spotify.com/v1/playlists/${PLAYLIST_ID}/tracks?limit=100`, {
      headers: { Authorization: `Bearer ${accessToken}` }
    });
    if (!res.ok) throw new Error("Failed to fetch playlist tracks");
    const data = await res.json();
    const items = (data.items || []).filter(i => i.track && i.track.uri);
    if (!items.length) throw new Error("No tracks in playlist");
    return items[Math.floor(Math.random() * items.length)].track;
  }

  async function playTrack(uri) {
    if (!deviceId) throw new Error("Spotify device not ready");
    await fetch(`https://api.spotify.com/v1/me/player/play?device_id=${deviceId}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${accessToken}` },
      body: JSON.stringify({ uris: [uri] })
    });
  }

  return { initPlayer, getRandomTrack, playTrack };
})();
