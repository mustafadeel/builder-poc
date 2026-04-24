---
name: auth0-quickstart
description: >
  Set up Auth0 authentication in a React SPA project. Use when the user wants to
  add Auth0 login, logout, user profile, protected routes, or authenticated API
  calls to a React application. Also use when the user asks about configuring
  Auth0Provider, using the useAuth0 hook, getting access tokens, or protecting
  routes with authentication.
---

# Auth0 Quickstart for React SPA

Add Auth0 authentication to a React single-page application using the `@auth0/auth0-react` SDK.

## Quick Start

### 1. Install the SDK

```bash
npm add @auth0/auth0-react
```

### 2. Configure environment variables

Create a `.env` file (or `.env.local` for Next.js) with Auth0 credentials:

```
VITE_AUTH0_DOMAIN={yourDomain}
VITE_AUTH0_CLIENT_ID={yourClientId}
```

For Next.js projects, use `NEXT_PUBLIC_` prefix instead of `VITE_`.

### 3. Wrap the app with Auth0Provider

In the application entry point (e.g., `src/main.tsx`):

```tsx
import { Auth0Provider } from '@auth0/auth0-react';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Auth0Provider
      domain={import.meta.env.VITE_AUTH0_DOMAIN}
      clientId={import.meta.env.VITE_AUTH0_CLIENT_ID}
      authorizationParams={{
        redirect_uri: window.location.origin
      }}
    >
      <App />
    </Auth0Provider>
  </StrictMode>
);
```

### 4. Add Login button

```tsx
import { useAuth0 } from "@auth0/auth0-react";

const LoginButton = () => {
  const { loginWithRedirect } = useAuth0();
  return <button onClick={() => loginWithRedirect()}>Log In</button>;
};
```

### 5. Add Logout button

```tsx
import { useAuth0 } from "@auth0/auth0-react";

const LogoutButton = () => {
  const { logout } = useAuth0();
  return (
    <button onClick={() => logout({ logoutParams: { returnTo: window.location.origin } })}>
      Log Out
    </button>
  );
};
```

### 6. Display user profile

```tsx
import { useAuth0 } from "@auth0/auth0-react";

const Profile = () => {
  const { user, isAuthenticated, isLoading } = useAuth0();

  if (isLoading) return <div>Loading...</div>;

  return isAuthenticated && user ? (
    <div>
      <img src={user.picture} alt={user.name} />
      <h2>{user.name}</h2>
      <p>{user.email}</p>
    </div>
  ) : null;
};
```

## Instructions

### Protected routes

Use `isAuthenticated` from the `useAuth0` hook to guard routes:

```tsx
import { useAuth0 } from "@auth0/auth0-react";
import { Navigate } from "react-router-dom";

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth0();

  if (isLoading) return <div>Loading...</div>;

  return isAuthenticated ? <>{children}</> : <Navigate to="/" />;
}
```

### Calling a protected API

1. Add `audience` to the Auth0Provider configuration:

```tsx
<Auth0Provider
  domain={import.meta.env.VITE_AUTH0_DOMAIN}
  clientId={import.meta.env.VITE_AUTH0_CLIENT_ID}
  authorizationParams={{
    redirect_uri: window.location.origin,
    audience: "YOUR_API_IDENTIFIER"
  }}
>
```

2. Use `getAccessTokenSilently` to attach a bearer token:

```tsx
const { getAccessTokenSilently } = useAuth0();

const callApi = async () => {
  const token = await getAccessTokenSilently();
  const response = await fetch("/api/protected", {
    headers: { Authorization: `Bearer ${token}` }
  });
  return response.json();
};
```

### Update Auth0 application callback URLs

**Before asking the user to test the application**, you MUST update the Auth0 application's URL settings to match the **actual running preview/dev server URL**.

**Do NOT assume `localhost`.** The app preview URL is often dynamically generated (e.g., a cloud preview URL, a tunneled URL, or a non-standard port). You must determine the real URL by:
1. Reading the dev server output after starting the app to find the actual URL it is serving on.
2. Checking for any preview URL provided by the hosting/preview environment.
3. Only falling back to `localhost` if the dev server output explicitly confirms it is serving on localhost.

Update all three URL fields on the Auth0 application to match the actual URL:

- **Allowed Callback URLs:** the actual app URL
- **Allowed Logout URLs:** the actual app URL
- **Allowed Web Origins:** the actual app URL (required for silent authentication)

These must be set on the Auth0 application or login/logout will fail with a callback mismatch error. Do not rely on the user to configure this manually — update it programmatically using the connected Auth0 integration (e.g., Auth0 MCP server) before proceeding to test.

For production, add the deployed URL to each field as well.

## Gotchas

- **Two separate Auth0 packages exist.** Use `@auth0/auth0-react` for SPAs, not `auth0-js` or `@auth0/nextjs-auth0` (which is for server-side Next.js).
- **Allowed Web Origins must be set** in the Auth0 Dashboard or silent token renewal will fail silently.
- **Never hardcode Auth0 credentials.** Always use environment variables. Add `.env` and `.env.local` to `.gitignore`.
- **`redirect_uri` must match exactly** what is configured in Auth0 Allowed Callback URLs, including protocol, host, port, and trailing slashes. Do not assume localhost — use the actual preview/dev server URL.
- **`isLoading` must be checked** before reading `isAuthenticated` or `user` to avoid rendering unauthenticated UI during initialization.
- **For Next.js App Router**, wrap the Auth0Provider in a client component (`"use client"` directive) since it uses React context.

## Key useAuth0 hook API

| Property / Method         | Description                                    |
|---------------------------|------------------------------------------------|
| `loginWithRedirect()`     | Redirects to Auth0 Universal Login page        |
| `logout()`                | Clears session and redirects to logout URL     |
| `getAccessTokenSilently()`| Returns an access token for API calls          |
| `user`                    | Authenticated user profile object              |
| `isAuthenticated`         | Boolean - whether user is logged in            |
| `isLoading`               | Boolean - whether Auth0 SDK is initializing    |
