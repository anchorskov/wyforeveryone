<!-- README.md -->
# Wyoming for Everyone

Static website scaffold for a Cloudflare Pages deployment.

## Structure

- `index.html`
- `css/styles.css`
- `js/main.js`
- `images/`

## Deploy

Upload the project root to Cloudflare Pages as a static site with no build command.

## Local Development

Run `./startDev.sh` to serve the site locally on `http://127.0.0.1:8788`.

Run `./startDev.sh 9000` to use a different port.

Run `./stop.sh` to stop the saved local dev server and any lingering project `wrangler dev` process.
