// @ts-check
import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";

// GitHub Pages serves the site at /kiln/, the docs link to "/api/..." like it was the root.
const base = "/kiln";

/** Prefixes root-relative links in Markdown with `base`. */
function remarkBaseLinks() {
  const walk = (node) => {
    if (node.type === "link" && node.url.startsWith("/") && !node.url.startsWith(base + "/")) {
      node.url = base + node.url;
    }
    node.children?.forEach(walk);
  };
  return walk;
}

export default defineConfig({
  site: "https://couchpotato007.github.io",
  base,
  markdown: { remarkPlugins: [remarkBaseLinks] },
  integrations: [
    starlight({
      title: "kiln",
      description: "A small UI library for Odin, built on Clay and raylib. Vibecoded.",
      logo: { src: "./src/assets/logo.svg" },
      social: [{ icon: "github", label: "GitHub", href: "https://github.com/couchpotato007/kiln" }],
      editLink: { baseUrl: "https://github.com/couchpotato007/kiln/edit/main/docs/" },
      customCss: ["./src/styles/kiln.css"],
      sidebar: [
        {
          label: "Start here",
          items: [
            { label: "What is it", slug: "" },
            { label: "Getting started", slug: "getting-started" },
            { label: "Problems", slug: "problems" },
            { label: "AI Disclaimer", slug: "ai" },
          ],
        },
        { label: "Guides", items: [{ autogenerate: { directory: "guides" } }] },
        { label: "API", items: [{ autogenerate: { directory: "api" } }] },
      ],
    }),
  ],
});
