// Worker's own post-processing detectors over the final texts (incl. the new surname + title check).
import { readFileSync, writeFileSync } from "node:fs";
const pp = await import("/Users/jason/Documents/RoastMate/cloud-worker/src/postprocess.js");
const [inp, outp] = process.argv.slice(2);
const rows = JSON.parse(readFileSync(inp, "utf8"));
const out = rows.map((r) => {
  const t = r.text || "", loc = r.request.locale, sit = r.request.situation;
  const d = pp.draftDefects(t, loc, sit);
  return { id: r.id, worker: {
    latin: d.latin, simplified: d.simplified, repeats: d.repeats, names: d.names, surname_titles: pp.surnameTitles(t, loc, sit),
    markdown_left: pp.stripMarkdown(t) !== t, word_list_tail: pp.stripWordListTail(t) !== t,
    situation_names: pp.situationNames(sit, loc) } };
});
writeFileSync(outp, JSON.stringify(out, null, 1));
console.log(out.filter((o) => o.worker.names.length || o.worker.latin.length || o.worker.simplified.length).map((o) => [o.id, o.worker.names, o.worker.latin, o.worker.simplified]));
