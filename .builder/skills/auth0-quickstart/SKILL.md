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

### Auth0 Dashboard configuration

Configure these URLs in Auth0 Dashboard > Applications > Settings:

- **Allowed Callback URLs:** `http://localhost:5173` (or your dev server URL)
- **Allowed Logout URLs:** `http://localhost:5173`
- **Allowed Web Origins:** `http://localhost:5173` (required for silent authentication)

For production, add your deployed URL to each field as well.

## Gotchas

- **Two separate Auth0 packages exist.** Use `@auth0/auth0-react` for SPAs, not `auth0-js` or `@auth0/nextjs-auth0` (which is for server-side Next.js).
- **Allowed Web Origins must be set** in the Auth0 Dashboard or silent token renewal will fail silently.
- **Never hardcode Auth0 credentials.** Always use environment variables. Add `.env` and `.env.local` to `.gitignore`.
- **`redirect_uri` must match exactly** what is configured in Auth0 Dashboard Allowed Callback URLs, including protocol, port, and trailing slashes.
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
