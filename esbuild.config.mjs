import * as esbuild from "esbuild"
import path from "node:path"
import { fileURLToPath } from "node:url"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const productsShim = path.join(
  __dirname,
  "app/javascript/controllers/helpers/nexrad_products_shim.cjs",
)
const packetsShim = path.join(
  __dirname,
  "app/javascript/controllers/helpers/nexrad_packets_shim.cjs",
)

const nexradShimsPlugin = {
  name: "nexrad-browser-shims",
  setup(build) {
    build.onResolve({ filter: /^\.\/products$/, namespace: "file" }, (args) => {
      if (args.resolveDir.includes(`${path.sep}nexrad-level-3-data${path.sep}`)) {
        return { path: productsShim }
      }
    })
    build.onResolve({ filter: /^\.\/packets$/, namespace: "file" }, (args) => {
      if (args.resolveDir.includes(`${path.sep}nexrad-level-3-data${path.sep}`)) {
        return { path: packetsShim }
      }
    })
    // Packet 10.js is required by our packets shim via package subpath.
    build.onResolve({ filter: /^\.\.\/packets$/, namespace: "file" }, (args) => {
      if (args.resolveDir.includes(`${path.sep}nexrad-level-3-data${path.sep}src${path.sep}headers`)) {
        return { path: packetsShim }
      }
    })
  },
}

const ctx = await esbuild.context({
  entryPoints: ["app/javascript/application.js"],
  bundle: true,
  sourcemap: true,
  format: "esm",
  outdir: "app/assets/builds",
  publicPath: "/assets",
  loader: {
    ".png": "file",
    ".svg": "file",
  },
  plugins: [nexradShimsPlugin],
  platform: "browser",
  // nexrad-level-3-data / seek-bzip expect Node's Buffer API in the browser.
  inject: [path.join(__dirname, "app/javascript/buffer_shim.js")],
  define: {
    global: "globalThis",
  },
})

if (process.argv.includes("--watch")) {
  await ctx.watch()
} else {
  await ctx.rebuild()
  await ctx.dispose()
}
