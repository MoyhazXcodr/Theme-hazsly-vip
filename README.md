# Hazsly One Full

Hazsly One Full is a dark premium UI pack for Pterodactyl that pushes both the React client area and the Blade-based admin area toward the mockup direction: graphite surfaces, violet-blue accents, cleaner cards, modern forms, calmer tables, and lighter motion.

## What this package does

- styles the user panel globally with `hazsly-one-user.css`
- styles the admin panel globally with `hazsly-one-admin.css`
- copies a Hazsly logo mark asset
- injects the user CSS import into `resources/scripts/components/App.tsx`
- injects an admin CSS link into a detected admin Blade layout
- rebuilds frontend assets
- clears Laravel caches
- saves a timestamped backup for rollback

## Realistic expectation

This gets a lot closer to the concept image in one install, but it is still a version-safe theme layer. A 1:1 replica of the concept needs page-by-page React layout rewrites and testing against the exact Pterodactyl version.

## One-line install

Change the default repo URL inside `install.sh` after you push this project, or export `REPO_URL` before running.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/YOURNAME/hazsly-one-full/main/install.sh)
```

If your panel path or web user is different:

```bash
export PANEL_DIR="/var/www/pterodactyl"
export WEB_USER="www-data"
export REPO_URL="https://github.com/YOURNAME/hazsly-one-full.git"
bash <(curl -fsSL https://raw.githubusercontent.com/YOURNAME/hazsly-one-full/main/install.sh)
```

## Local install

```bash
git clone https://github.com/YOURNAME/hazsly-one-full.git
cd hazsly-one-full
bash install.sh
```

## Uninstall

```bash
bash uninstall.sh
```

## Doctor

```bash
bash doctor.sh
```

## Notes

- best fit: Debian or Ubuntu panel VPS
- default panel path: `/var/www/pterodactyl`
- default web user: `www-data`
- install script will attempt to install missing dependencies on apt-based systems
- if the admin layout path differs a lot from stock, the script warns instead of breaking the install
