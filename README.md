# GitHub Pages Deployment (Actions Only) Fork this for your repo

This repository deploys a static website using GitHub Actions.

There are no local deployment scripts.  
Production updates only when code is merged into `main`.

---

## How Deployment Works

1. A Pull Request is opened targeting `main`.
2. GitHub Actions runs verification checks.
3. If checks pass, the PR can be merged.
4. When `main` updates, the site is deployed automatically.

Deployment happens only from the `main` branch.

---

## Verification Checks

Before deployment, the workflow ensures:

- `index.html` exists
- No `TODO` or `FIXME` markers remain
- All `.html` files are readable
- No broken local `href` or `src` file references exist

If any check fails, deployment is blocked.

---

## Required Repository Setting

Go to:

Settings → Pages

Set:

Source: **GitHub Actions**

---

## Recommended Branch Protection

To prevent accidental production issues:

Settings → Branches → Add rule for `main`

Enable:

- Require pull request before merging
- Require status checks to pass before merging
- Require branches to be up to date before merging

This ensures production is always verified before deployment.

---

## Development Workflow
```
git checkout -b feature-x
```
# Make changes
```
git commit -m "feature update"
git push origin feature-x
```

Open a Pull Request into `main`.

Once merged, the site deploys automatically.
