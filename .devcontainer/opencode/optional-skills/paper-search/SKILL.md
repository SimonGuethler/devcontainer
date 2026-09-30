---
name: paper-search
description: Find academic papers across scholarly sources, download available PDFs, and read paper text using the Paper Search CLI.
---

# Paper Search CLI

Use the pinned published package through the shell:

```bash
uvx --with 'mcp<2' --from paper-search-mcp==0.1.4 paper-search sources
uvx --with 'mcp<2' --from paper-search-mcp==0.1.4 paper-search search "retrieval augmented generation" -s pubmed,openalex,crossref -n 5
uvx --with 'mcp<2' --from paper-search-mcp==0.1.4 paper-search download arxiv 2106.12345 -o ./downloads
uvx --with 'mcp<2' --from paper-search-mcp==0.1.4 paper-search read arxiv 2106.12345 -o ./downloads
```

Use `--help` for command options. Select relevant sources and bound results:
`-n` is per source, not a total limit. Search returns JSON including `errors`,
`source_results`, and deduplicated `papers`. A successful exit does not prove
every source succeeded. Download results can contain an error message in `path`;
check that an actual PDF exists. Read may return metadata or an abstract instead
of full text; distinguish these when summarizing or citing. Redirect long results
to a task-local file and inspect only needed fields or passages.

## Default usage

Always pass explicit `-s` sources rather than running an all-source sweep —
background 429s and bot blocks otherwise surface as silent zeros.

Good starting points: `-s openalex,crossref` for general topics;
`-s pubmed,pmc,europepmc` for biomedical topics. A source can legitimately
return 0 for an out-of-domain query (for example `pmc` on a computer-science
topic); retry with a domain-typical query before treating the source as broken.

## Interpreting failures

Source reliability is not stable: keyless endpoints rate-limit datacenter IPs
(HTTP 429), sites bot-challenge scrapers, endpoints move, and the pinned
package can have bugs. Most failures surface as 0 results with empty `errors`
and are indistinguishable from a genuinely empty result. For any 0-result
query, retry the source once, cross-check a different source, and try a
domain-typical query before concluding anything. A visible error in `errors`
means the source itself failed: switch sources instead of retrying, and report
the limitation.

Some durable source behaviors:

- `arxiv` has no API key, so its search rate limit cannot be raised with
  credentials; abstract pages by known ID (`arxiv.org/abs/<id>`, plain curl)
  keep working either way — search alternates for the ID, then fetch the abs
  page.
- `semantic` rate-limits without `SEMANTIC_SCHOLAR_API_KEY`.
- `unpaywall` is not a search source; it is a DOI-keyed PDF fallback and stays
  inert without an email configured.

Set `PAPER_SEARCH_MCP_UNPAYWALL_EMAIL` to activate the unpaywall fallback, and
`SEMANTIC_SCHOLAR_API_KEY` to raise the semantic scholar rate limit; other
optional keys: `CORE_API_KEY`, `DOAJ_API_KEY`, `OPENAIRE_API_KEY`,
`ACM_API_KEY`, `IEEE_API_KEY`, `CITESEERX_API_KEY`.

Optional credentials use `PAPER_SEARCH_MCP_*` environment variables or
`~/.config/paper-search-mcp/.env`. Existing OpenCode MCP `environment` settings
apply only to the MCP process; configure equivalent CLI credentials before using
a source that requires them. Do not print credentials.

Version 0.1.4 shares source implementations with MCP, but its CLI does not expose
the server's `download_with_fallback`. If a direct download fails, use another
available source explicitly and report any retrieval limitations. The MCP server
remains an opt-in alternative (`--paper-search-mcp`) for that functionality.
