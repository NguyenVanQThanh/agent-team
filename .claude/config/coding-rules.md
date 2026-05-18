# Coding Rules — Agent Team Standards

> **Mandatory reading** for all dev teammates before modifying any source code.
> The leader must reference this file in every task's shared-context block.

---

## 1. Protected Files — Never Edit

Teammates MUST NOT read or modify these files under any circumstances:

| Category | Examples |
|---|---|
| Environment secrets | `.env`, `.env.local`, `.env.*.local`, `.env.development`, `.env.production`, `.env.staging`, `.env.test` |
| Credentials & keys | `*.pem`, `*.key`, `secrets.json`, `service-account.json` |
| Production platform config | `firebase.json`, `vercel.json`, `netlify.toml`, `app.config.js/ts` (when containing prod settings) |
| Repo/project settings | `.git/config`, IDE workspace files (`.vscode/settings.json`, `.idea/`) unless the task explicitly targets them |

**Allowed to read and edit freely:**

- `.env.example`, `.env.sample`, `.env.template` — placeholder values only, always safe
- Dev/test config files when the task explicitly names them in acceptance criteria

**If a task requires a real `.env*` value:** write `status=blocked`, `notes=needs env var <VAR_NAME> — route to human` and stop. Do not guess values.

---

## 2. File Header Comments

Every source file you **create** or **significantly modify** must carry a header block.
Place it at the very top of the file, before any imports or package declarations.
Use the appropriate syntax for the language:

### JavaScript / TypeScript

```typescript
/**
 * @file        <filename>.<ext>
 * @description <one-line description of what this file does>
 *
 * @createdAt   YYYY-MM-DD
 * @createdBy   <dev persona, e.g. dev8>
 * @updatedAt   YYYY-MM-DD
 * @updatedBy   <dev persona>
 */
```

### Python

```python
"""
File:        <filename>.py
Description: <one-line description>

Created at:  YYYY-MM-DD
Created by:  <dev persona>
Updated at:  YYYY-MM-DD
Updated by:  <dev persona>
"""
```

### Go

```go
// Package <name> — <one-line description>
//
// File:       <filename>.go
// Created at: YYYY-MM-DD   Created by: <dev persona>
// Updated at: YYYY-MM-DD   Updated by: <dev persona>
```

### Java / Kotlin

```java
/**
 * <ClassName> — <one-line description>
 *
 * @createdAt  YYYY-MM-DD
 * @createdBy  <dev persona>
 * @updatedAt  YYYY-MM-DD
 * @updatedBy  <dev persona>
 */
```

### Shell (Bash)

```bash
#!/usr/bin/env bash
# File:        <filename>.sh
# Description: <one-line description>
# Created at:  YYYY-MM-DD   Created by: <dev persona>
# Updated at:  YYYY-MM-DD   Updated by: <dev persona>
```

### Dart / Flutter

```dart
/// File:        <filename>.dart
/// Description: <one-line description>
///
/// Created at:  YYYY-MM-DD
/// Created by:  <dev persona>
/// Updated at:  YYYY-MM-DD
/// Updated by:  <dev persona>
```

### SQL

```sql
-- File:        <filename>.sql
-- Description: <one-line description>
-- Created at:  YYYY-MM-DD   Created by: <dev persona>
-- Updated at:  YYYY-MM-DD   Updated by: <dev persona>
```

---

## 3. Business Handler / Service Function Comments

For any function, method, or handler that contains **business logic** — not purely utility/glue code — you must add:

1. A **structured docstring before the function** listing every major process step.
2. **Numbered inline comments inside the body** matching each step in the header list.

### Why

Business logic is the hardest code to follow at a glance. Step-numbered comments let a reviewer jump between the intention (header list) and the implementation (body markers) without reading every line.

### Template

```
/**
 * <FunctionName> — <one-line purpose>
 *
 * Process:
 *   1. <First logical step>
 *   2. <Second logical step>
 *   3. <Third logical step>
 *   ...
 *
 * @param  <name>  <description>
 * @returns        <description>
 * @throws         <error type and when>
 */
```

### Full example (TypeScript)

```typescript
/**
 * processOrderPayment — Handles the full payment lifecycle for an order.
 *
 * Process:
 *   1. Validate order exists and belongs to the requesting user
 *   2. Check inventory availability for all line items
 *   3. Reserve stock (optimistic lock)
 *   4. Charge via payment gateway
 *   5. On success → create transaction record + emit OrderPaid event
 *   6. On failure → release stock reservation + propagate gateway error
 *
 * @param  orderId  UUID of the order to pay
 * @param  userId   UUID of the authenticated user
 * @returns         PaymentResult with chargeId on success
 * @throws          NotFoundError if order not found or not owned by user
 * @throws          InsufficientStockError if inventory check fails
 */
async function processOrderPayment(orderId: string, userId: string): Promise<PaymentResult> {
  // 1. Validate order ownership
  const order = await orderRepo.findByIdAndUser(orderId, userId);
  if (!order) throw new NotFoundError('Order');

  // 2. Check inventory
  const available = await inventoryService.checkAll(order.lineItems);
  if (!available) throw new InsufficientStockError();

  // 3. Reserve stock
  await inventoryService.reserve(order.lineItems);

  try {
    // 4. Charge payment
    const charge = await paymentGateway.charge(order.total, order.paymentMethod);

    // 5. Record and emit
    await transactionRepo.create({ orderId, chargeId: charge.id });
    eventBus.emit('OrderPaid', { orderId });

    return { success: true, chargeId: charge.id };
  } catch (err) {
    // 6. Release reservation on failure
    await inventoryService.release(order.lineItems);
    throw err;
  }
}
```

### Rules

- List **every major step** in the header docstring — no hidden logic.
- Inside the body, mark each step with `// <N>. <action>` matching the header number.
- Comment only the **first line** of a multi-line block for a step; don't repeat it on every line.
- If a function has fewer than 3 logical steps and is obvious from naming, a one-liner description is enough — skip the numbered list.

---

## 4. Inline Comments

- Only comment the **WHY**, never the WHAT. Identifiers already say what.
- Bad: `i++ // increment i`
- Good: `retryCount++ // gateway is flaky under load; retry up to MAX_RETRIES`
- Use the language's native single-line token (`//`, `#`, `--`, `///`).
- Do NOT write block comments inside function bodies — numbered step markers (rule 3) are the exception.

---

## 5. General Code Hygiene

- **No dead code.** Delete commented-out blocks before marking a task done.
- **No unexplained TODOs.** If something is out of scope, note it in your `notes=` status field, not in the code.
- **Match existing style.** Tabs vs spaces, brace placement, import order — follow what's already there in adjacent files.
- **Run tests/lint before declaring done.** See AGENTS.md "Project rules" for the smoke-test requirement.
