# Gateway Proxied Services

Public gateway: `https://api.production-eu.tickets.mdlbeast.net`

- **AccessControl**
  - Internal: `https://accesscontrol.internal.production-eu.tickets.mdlbeast.net`
  - Public: `https://api.production-eu.tickets.mdlbeast.net/access/...`

- **Catalogue**
  - Internal: `https://catalogue.internal.production-eu.tickets.mdlbeast.net`
  - Public: `https://api.production-eu.tickets.mdlbeast.net/catalogue/...`

- **Customers**
  - Internal: `https://customers.internal.production-eu.tickets.mdlbeast.net`
  - Public: `https://api.production-eu.tickets.mdlbeast.net/customers/...`

- **DistributionPortal**
  - Internal: `https://dp.internal.production-eu.tickets.mdlbeast.net`
  - Public: `https://api.production-eu.tickets.mdlbeast.net/dp/...`

- **Extensions**
  - Internal: `https://extensions.internal.production-eu.tickets.mdlbeast.net`
  - Public: `https://api.production-eu.tickets.mdlbeast.net/extensions/...`

- **Integration**
  - Internal: `https://integration.internal.production-eu.tickets.mdlbeast.net`
  - Public: `https://api.production-eu.tickets.mdlbeast.net/integrations/...`

- **Inventory**
  - Internal: `https://inventory.internal.production-eu.tickets.mdlbeast.net`
  - Public: `https://api.production-eu.tickets.mdlbeast.net/inventory/...`

- **Marketplace**
  - Internal: `https://marketplace.internal.production-eu.tickets.mdlbeast.net`
  - Public: `https://api.production-eu.tickets.mdlbeast.net/marketplace/...`

- **Media**
  - Internal: `https://media.internal.production-eu.tickets.mdlbeast.net`
  - Public: `https://api.production-eu.tickets.mdlbeast.net/media/...`

- **Organizations**
  - Internal: `https://organizations.internal.production-eu.tickets.mdlbeast.net`
  - Public: `https://api.production-eu.tickets.mdlbeast.net/organizations/...`

- **Pricing**
  - Internal: `https://pricing.internal.production-eu.tickets.mdlbeast.net`
  - Public: `https://api.production-eu.tickets.mdlbeast.net/pricing/...`

- **Reporting**
  - Internal: `https://reporting.internal.production-eu.tickets.mdlbeast.net`
  - Public: `https://api.production-eu.tickets.mdlbeast.net/reporting/...`

- **Sales**
  - Internal: `https://sales.internal.production-eu.tickets.mdlbeast.net`
  - Public: `https://api.production-eu.tickets.mdlbeast.net/sales/...`

- **Transfer**
  - Internal: `https://transfer.internal.production-eu.tickets.mdlbeast.net`
  - Public: `https://api.production-eu.tickets.mdlbeast.net/transfer/...`

## Notes

- All proxied routes require authentication (Auth0 Bearer token).
- Most routes also require `x-api-version` header (e.g., `x-api-version: 3`).
- The gateway's own `/health` endpoint is the only unauthenticated endpoint.
- Internal addresses are loaded at runtime from SSM (`/prod/tp/InternalServices/*`).
