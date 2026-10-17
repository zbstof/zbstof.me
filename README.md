# zbstof.me

Personal page served at https://zbstof.me from the S3 bucket `zbstof.me`.
`www.zbstof.me` redirects to it.

- `web/`: the page, published as is. HTML files are rendered through
  Terraform's `templatefile` to stamp the stylesheet URL with `?v=<md5>`, so
  `${...}` in HTML is a template expression.
- `terraform/`: the site bucket, the www redirect bucket, website settings and
  the uploaded files. State is in `zbstof-terraform-state` under `zbstof.me/`.
- DNS for both hostnames lives in `~/Play/zbstof.me-infra`.

## Deploy

```bash
scripts/deploy-site.sh          # plan
scripts/deploy-site.sh --apply  # plan and apply
```

Preview locally with `python3 -m http.server -d web`. The stylesheet link
carries an unrendered `${css_v}` there, which the server ignores.
