---
name: react-builder
description: >
  Integrate Builder.io's visual CMS with a React application. Use when the user
  wants to set up Builder.io in a React or Next.js project, register custom React
  components for the visual editor, fetch and render Builder content, create
  editable pages or sections, configure the Builder SDK, or connect a React app
  to Builder.io's headless CMS. Also use when the user asks about
  BuilderComponent, Builder.registerComponent, builder-registry, content fetching,
  or making components drag-and-droppable in the Builder visual editor.
---

# React + Builder.io Integration

Set up Builder.io's visual headless CMS in a React application so non-developers can create and edit pages using your custom React components.

## Quick Start

### 1. Install the Builder.io React SDK

```bash
npm install @builder.io/react
```

For Next.js App Router with React Server Components, also install:

```bash
npm install @builder.io/sdk
```

### 2. Initialize Builder with your API key

```tsx
import { builder } from '@builder.io/react';

builder.init('YOUR_BUILDER_PUBLIC_API_KEY');
```

Store the API key in environment variables:

```
# .env.local
NEXT_PUBLIC_BUILDER_API_KEY=your-key-here
# or for Vite:
VITE_BUILDER_API_KEY=your-key-here
```

### 3. Fetch and render Builder content

```tsx
import { BuilderComponent, builder } from '@builder.io/react';

builder.init(process.env.NEXT_PUBLIC_BUILDER_API_KEY!);

export default async function Page({ params }: { params: { page: string[] } }) {
  const content = await builder
    .get('page', {
      url: '/' + (params.page?.join('/') || ''),
    })
    .toPromise();

  return <BuilderComponent model="page" content={content} />;
}
```

### 4. Register custom components

Create a `builder-registry.ts` file (must have `"use client"` directive in Next.js App Router):

```tsx
"use client";
import { Builder } from '@builder.io/react';
import { MyHero } from './components/MyHero';

Builder.registerComponent(MyHero, {
  name: 'MyHero',
  inputs: [
    { name: 'title', type: 'string', defaultValue: 'Hello World' },
    { name: 'subtitle', type: 'longText', defaultValue: '' },
    { name: 'image', type: 'file', allowedFileTypes: ['jpeg', 'png', 'webp'] },
    { name: 'ctaText', type: 'string', defaultValue: 'Learn More' },
    { name: 'ctaUrl', type: 'url' },
  ],
});
```

Import the registry file early in your app entry point so components are available to the editor.

## Instructions

### Setting up a catch-all route (Next.js App Router)

Create `app/[...page]/page.tsx` to let Builder handle any URL:

```tsx
import { builder } from '@builder.io/sdk';
import { RenderBuilderContent } from '@/components/builder';

builder.init(process.env.NEXT_PUBLIC_BUILDER_API_KEY!);

export default async function Page({ params }: { params: { page: string[] } }) {
  const content = await builder
    .get('page', {
      url: '/' + (params.page?.join('/') || ''),
    })
    .toPromise();

  if (!content) {
    return notFound();
  }

  return <RenderBuilderContent content={content} model="page" />;
}
```

### Builder content wrapper component

Create `components/builder.tsx`:

```tsx
"use client";
import { BuilderComponent, useIsPreviewing } from '@builder.io/react';
import '../builder-registry';

export function RenderBuilderContent({
  content,
  model,
}: {
  content: any;
  model: string;
}) {
  const isPreviewing = useIsPreviewing();

  if (!content && !isPreviewing) return null;

  return <BuilderComponent content={content} model={model} />;
}
```

### Input type mapping for custom components

When registering components, map TypeScript prop types to Builder input types:

| TypeScript type       | Builder input type | Notes                                       |
|-----------------------|-------------------|---------------------------------------------|
| `string`              | `string`          | Single-line text                            |
| `string` (long)      | `longText`        | Multi-line text                             |
| `string` (rich)      | `richText`        | HTML rich text editor                       |
| `number`              | `number`          | Numeric input                               |
| `boolean`             | `boolean`         | Toggle switch                               |
| `string` (URL)       | `url`             | URL input with validation                   |
| `string` (image)     | `file`            | File picker, use `allowedFileTypes`         |
| `string` (color)     | `color`           | Color picker                                |
| `string` (enum)      | `text` + `enum`   | Dropdown from array of options              |
| `Array<T>`           | `list`            | Repeatable items, needs `subFields`         |
| `Object`             | `object`          | Nested fields, needs `subFields`            |
| `React.ReactNode`    | `blocks`          | Nested Builder blocks / children            |

### Passing data to Builder content

```tsx
<BuilderComponent
  model="page"
  content={content}
  data={{ products, user }}
  context={{ formatPrice, analytics }}
/>
```

- `data` props are reactive and accessible as `state.products` in Builder bindings.
- `context` props are non-reactive (functions, services) accessible as `context.formatPrice`.

### Using Builder for sections (not full pages)

Fetch a specific section model instead of a page:

```tsx
const banner = await builder.get('announcement-bar').toPromise();

return <BuilderComponent model="announcement-bar" content={banner} />;
```

Create custom models in Builder Dashboard > Models for sections, data, and custom entries.

### Querying content with filters

```tsx
const content = await builder
  .get('blog-post', {
    query: {
      'data.slug': 'my-post',
      'data.published': true,
    },
    options: {
      limit: 10,
    },
  })
  .toPromise();
```

### Using API v3

For improved performance and scalability:

```tsx
builder.apiVersion = 'v3';
```

## Gotchas

- **Never use `type: "enum"` in component inputs.** It causes silent failures. Use `type: "text"` with an `enum` array instead:
  ```tsx
  { name: 'size', type: 'text', enum: ['small', 'medium', 'large'] }
  ```
- **`list` and `object` inputs require `defaultValue`.** Always set `defaultValue: []` for lists and `defaultValue: {}` for objects or the visual editor will break.
- **Two separate `builder.init()` calls are needed in Next.js App Router.** One server-side via `@builder.io/sdk` for content fetching, one client-side via `@builder.io/react` for rendering. This is intentional.
- **`builder-registry.ts` must be imported in the client component** that renders BuilderComponent, not in a server component.
- **Dynamic imports in the registry must use relative paths** from the registry file location, not aliases or absolute paths.
- **Store the API key in `.env.local`**, not committed to the repo. Add it to your deployment environment separately.
- **The `"use client"` directive is required** on both the builder wrapper component and the registry file in Next.js App Router.
- **For the lite build** (`@builder.io/react/lite`), you must manually import any built-in Builder components you use. The lite version excludes default components to reduce bundle size.
- **CSP headers can block the visual editor.** If the editor preview is blank, check that your Content Security Policy allows framing from `builder.io`.
