<h1 align="center" style="border-bottom: none">
  <div>
    SignFlow
  </div>
</h1>
<h3 align="center">
  Secure document signing, self-hosted or run as a service
</h3>

> SignFlow is built on [DocuSeal](https://github.com/docusealco/docuseal) and is
> distributed under the same AGPL-3.0 licence. All features that upstream
> restricts to Pro/Console subscribers are enabled here, with no external
> licence required, plus self-serve sign-up and subscription billing.

> **Licence note.** AGPL-3.0 section 13 requires that anyone who uses this over
> a network be offered the complete corresponding source, including your
> modifications. `LICENSE_ADDITIONAL_TERMS` (section 7(b)) additionally requires
> that the DocuSeal attribution stay visible in interactive user interfaces —
> it is rendered beneath the product name on signing pages and must not be
> removed. Take your own legal advice before selling access.

---

## Differences from the official project

| Feature | DocuSeal official | SignFlow |
|---|:---:|:---:|
| Signature & PDF forms | ✅ | ✅ |
| API & Webhooks | ✅ | ✅ |
| User management (admin only) | ✅ | ✅ |
| **User roles (Editor, Viewer)** | Pro | ✅ |
| **Advanced personalization (logo, branding)** | Pro | ✅ |
| **Bulk send (CSV / XLSX import)** | Pro | ✅ |
| **Automated email reminders** | Pro | ✅ |
| **Reply-To in email templates** | Pro | ✅ |
| **SSO / SAML 2.0** | Pro | ✅ |
| **Signing order & unique signers enforcement** | Pro | ✅ |
| **Expirable download links** | Pro | ✅ |
| **Form delegation** | Pro | ✅ |
| **Configurable Decline button** | Pro | ✅ |
| **Efficient pagination for large datasets** | Pro | ✅ |
| **Multi-account (tenants) management** | Pro | ✅ |

---

## Full feature list

- PDF form fields builder (WYSIWYG)
- 12 field types available (Signature, Date, File, Checkbox, etc.)
- Multiple submitters per document
- Automated emails via custom SMTP
- File storage on disk, AWS S3, Google Storage, or Azure
- Automatic PDF eSignature + signature verification
- **User roles: Admin, Editor, Viewer**
- **Personalization: company logo, custom branding**
- **Bulk send from CSV or XLSX files**
- **Automatic email reminders to recipients**
- **SSO / SAML 2.0** (requires SAML configuration)
- **Configurable Reply-To in email templates**
- **Enforced signing order and unique signers**
- **Form delegation**
- Mobile-optimized interface
- 7 UI languages, signing available in 14 languages
- REST API and Webhooks for integrations
- Embeddable signing form ([React](https://github.com/docusealco/docuseal-react), [Vue](https://github.com/docusealco/docuseal-vue), [Angular](https://github.com/docusealco/docuseal-angular))

---

## Deployment

### Docker (recommended)

```sh
docker run --name docuseal -p 3000:3000 -v .:/data docuseal/docuseal
```

### Docker Compose

```sh
curl https://raw.githubusercontent.com/docusealco/docuseal/master/docker-compose.yml > docker-compose.yml
sudo HOST=your-domain.com docker compose up
```

### Local development

```sh
git clone <this-repo>
cd docuseal
bundle install
yarn install
rails db:create db:migrate
bin/dev
```

---

## How it works

Pro features in the official DocuSeal are gated via the CanCan permission system using ability symbols (`:saml_sso`, `:bulk_send`, `:countless`, etc.) that are normally injected by a closed-source proprietary plugin. In this fork:

- **[lib/ability.rb](lib/ability.rb)** — All Pro permission symbols are granted to every authenticated user.
- **[app/models/user.rb](app/models/user.rb)** — The `editor` and `viewer` roles are declared as constants.
- **[app/views/templates/edit.html.erb](app/views/templates/edit.html.erb)** — `data-with-conditions`, `data-with-formula`, and `data-with-dynamic-documents` are set to `true` so the template builder enables conditional fields, formula fields, and dynamic documents (these are gated client-side via data attributes, not CanCan).
- **Placeholder views** — All "Unlock with DocuSeal Pro" upgrade banners have been removed.
- **Navbar** — The "Upgrade" button and "Pro" badge have been removed.

---

## Original project

This fork is based on [DocuSeal](https://github.com/docusealco/docuseal) by DocuSeal LLC, distributed under the AGPLv3 license with Section 7(b) additional terms.

- Official website: [docuseal.com](https://www.docuseal.com)
- To support the original project: [docuseal.com/pricing](https://www.docuseal.com/pricing)

## License

Distributed under the AGPLv3 License with Section 7(b) Additional Terms. See [LICENSE](https://github.com/docusealco/docuseal/blob/master/LICENSE) and [LICENSE_ADDITIONAL_TERMS](https://github.com/docusealco/docuseal/blob/master/LICENSE_ADDITIONAL_TERMS) for more information.  
Unless otherwise noted, all files © 2023-2026 DocuSeal LLC.
